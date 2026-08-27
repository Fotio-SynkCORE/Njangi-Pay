import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

/// Real Firestore reads/writes for groups and the ledger, matching the
/// schema in firestore_schema.md. `memberIds` is a denormalized array on
/// the group doc (in addition to the members subcollection which holds
/// per-member role/status) purely so "my groups" can be queried directly
/// with arrayContains instead of a slower collection-group query.
class GroupService {
  final _db = FirebaseFirestore.instance;
  final _notifications = NotificationService();
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  /// Live stream of the groups the signed-in user belongs to.
  Stream<List<NjangiGroup>> myGroups() {
    return _db
        .collection('njangiGroups')
        .where('memberIds', arrayContains: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(NjangiGroup.fromDoc).toList());
  }

  Stream<NjangiGroup> group(String groupId) {
    return _db
        .collection('njangiGroups')
        .doc(groupId)
        .snapshots()
        .map(NjangiGroup.fromDoc);
  }

  /// All users on the platform except those already in this group --
  /// browsed like a WhatsApp "add participant" list. Filtering happens
  /// client-side (name/email substring match) since Firestore doesn't do
  /// case-insensitive text search natively -- fine at this app's scale.
  Future<List<AppUser>> browsableUsers(List<String> excludeIds) async {
    final snap = await _db.collection('users').get();
    return snap.docs
        .where((d) => !excludeIds.contains(d.id))
        .map(AppUser.fromDoc)
        .toList();
  }

  /// Secretary adds an existing app user to the group: creates their
  /// members/{uid} doc, adds them to the denormalized memberIds array,
  /// and logs it. Firestore rules require the caller to be secretary for
  /// both the members-subcollection create and the njangiGroups update.
  Future<void> addMember(String groupId, String userId, int rotationPosition) async {
    final groupRef = _db.collection('njangiGroups').doc(groupId);

    await groupRef.collection('members').doc(userId).set({
      'userId': userId,
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
      'status': 'active',
      'rotationPosition': rotationPosition,
    });

    await groupRef.update({
      'memberIds': FieldValue.arrayUnion([userId]),
      'rotationOrder': FieldValue.arrayUnion([userId]),
    });

    await _writeAudit(
      groupId: groupId,
      action: 'member_added',
      targetId: userId,
      after: {'role': 'member'},
    );

    final group = await groupRef.get();
    await _notifications.notify(
      recipientUserId: userId,
      title: 'Added to a Njangi group',
      body: 'You were added to ${group.data()?['name'] ?? 'a group'}.',
      type: 'member_added',
      groupId: groupId,
    );
  }

  // --- Loans (Standard tier+) ------------------------------------------
  //
  // Above this XAF amount, the request form requires collateral -- large
  // enough that a secretary would reasonably want more than a promise
  // before approving. Adjust to whatever your group culture expects.
  static const collateralThreshold = 100000;

  Stream<List<LoanEntry>> loans(String groupId) {
    return _db
        .collection('njangiGroups')
        .doc(groupId)
        .collection('loans')
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(LoanEntry.fromDoc).toList());
  }

  Future<void> requestLoan(
    String groupId,
    int amount,
    DateTime dueDate,
    String momoNumber,
    String? collateral,
  ) async {
    final doc = await _db.collection('njangiGroups').doc(groupId).collection('loans').add({
      'memberId': _uid,
      'amount': amount,
      'status': 'requested',
      'requestedAt': FieldValue.serverTimestamp(),
      'dueDate': Timestamp.fromDate(dueDate),
      'momoNumber': momoNumber,
      'collateral': collateral,
      'outstandingBalance': amount,
      'lateFeeApplied': false,
      'dueSoonNotified': false,
      'overdueNotified': false,
    });
    await _writeAudit(groupId: groupId, action: 'loan_requested', targetId: doc.id, after: {'amount': amount});
  }

  Future<void> rejectLoan(String groupId, String loanId) async {
    await _db.collection('njangiGroups').doc(groupId).collection('loans').doc(loanId).update({
      'status': 'rejected',
      'approvedBy': _uid,
    });
    await _writeAudit(groupId: groupId, action: 'loan_status_changed', targetId: loanId, after: {'status': 'rejected'});
  }

  /// Called only after the secretary confirms disbursement through the
  /// PIN-entry screen (simulating actually withdrawing and sending the
  /// money via her own MoMo) -- so unlike a plain status flip, this is
  /// the moment the money is treated as genuinely gone, and it's the only
  /// place a loanDisbursement ledger entry gets created.
  Future<void> disburseLoan(String groupId, String loanId) async {
    final ref = _db.collection('njangiGroups').doc(groupId).collection('loans').doc(loanId);
    final loanDoc = await ref.get();
    final memberId = loanDoc.data()?['memberId'] as String?;
    final amount = loanDoc.data()?['amount'] as int?;
    if (memberId == null || amount == null) return;

    await ref.update({'status': 'active', 'approvedBy': _uid});

    await _db.collection('njangiGroups').doc(groupId).collection('ledger').add({
      'type': 'loanDisbursement',
      'memberId': memberId,
      'amount': amount,
      'date': FieldValue.serverTimestamp(),
      'recordedBy': _uid,
      'status': 'verified',
    });

    await _notifications.notify(
      recipientUserId: memberId,
      title: 'Loan approved',
      body: 'Your $amount XAF loan was disbursed to your MoMo number.',
      type: 'loan_approved',
      groupId: groupId,
    );

    await _writeAudit(groupId: groupId, action: 'loan_status_changed', targetId: loanId, after: {'status': 'active'});
  }

  /// Member submits a repayment -- same trust model as a contribution now:
  /// it lands as "pending" with an optional screenshot, and only actually
  /// reduces the loan's outstanding balance once the secretary verifies
  /// it via setEntryStatus (below). loanId links the ledger entry back to
  /// the loan so that verification step knows which loan to update.
  Future<void> repayLoan(String groupId, String loanId, int amount, {String? screenshotUrl}) async {
    await _db.collection('njangiGroups').doc(groupId).collection('ledger').add({
      'type': 'loanRepayment',
      'memberId': _uid,
      'amount': amount,
      'date': FieldValue.serverTimestamp(),
      'recordedBy': _uid,
      'status': 'pending',
      'loanId': loanId,
      if (screenshotUrl != null) 'sourceScreenshotUrl': screenshotUrl,
    });
    await _writeAudit(groupId: groupId, action: 'loan_repayment_submitted', targetId: loanId, after: {'amount': amount});
  }

  /// Secretary marks an overdue loan late and applies the flat late fee
  /// to its outstanding balance -- manually triggered, not automatic.
  /// Secretary manually decides the fine amount for a member who missed
  /// their loan due date -- writes a normal verified 'fine' ledger entry
  /// (same type contributions/fines already use) rather than silently
  /// inflating the loan balance by a fixed percentage.
  Future<void> addLoanFine(String groupId, String loanId, String memberId, int fineAmount) async {
    await _db.collection('njangiGroups').doc(groupId).collection('ledger').add({
      'type': 'fine',
      'memberId': memberId,
      'amount': fineAmount,
      'date': FieldValue.serverTimestamp(),
      'recordedBy': _uid,
      'status': 'verified',
      'loanId': loanId,
    });
    await _db.collection('njangiGroups').doc(groupId).collection('loans').doc(loanId).update({
      'lateFeeApplied': true,
    });
    await _writeAudit(groupId: groupId, action: 'loan_fine_added', targetId: loanId, after: {'fine': fineAmount});
    await _notifications.notify(
      recipientUserId: memberId,
      title: 'Fine applied for late loan repayment',
      body: 'A $fineAmount XAF fine was added for missing your loan due date.',
      type: 'loan_fine',
      groupId: groupId,
    );
  }

  /// Checks active loans for this group and, if a due date is within 2
  /// days or has passed, sends a one-time notification to the borrower.
  /// Client-triggered on screen load (no cron on the free plan) -- call
  /// this from LoansScreen/GroupDetailScreen, not scheduled server-side.
  Future<void> checkLoanDueDates(String groupId) async {
    final snap = await _db
        .collection('njangiGroups')
        .doc(groupId)
        .collection('loans')
        .where('status', isEqualTo: 'active')
        .get();

    final now = DateTime.now();
    for (final doc in snap.docs) {
      final d = doc.data();
      final dueDate = (d['dueDate'] as Timestamp?)?.toDate();
      final memberId = d['memberId'] as String?;
      if (dueDate == null || memberId == null) continue;

      final overdueNotified = d['overdueNotified'] ?? false;
      final dueSoonNotified = d['dueSoonNotified'] ?? false;

      if (now.isAfter(dueDate) && !overdueNotified) {
        await doc.reference.update({'overdueNotified': true});
        await _notifications.notify(
          recipientUserId: memberId,
          title: 'Loan repayment overdue',
          body: 'Your loan due date has passed. Please repay soon to avoid a fine.',
          type: 'loan_overdue',
          groupId: groupId,
        );
      } else if (!now.isAfter(dueDate) &&
          dueDate.difference(now).inDays <= 2 &&
          !dueSoonNotified) {
        await doc.reference.update({'dueSoonNotified': true});
        await _notifications.notify(
          recipientUserId: memberId,
          title: 'Loan due soon',
          body: 'Your loan repayment is due in the next couple of days.',
          type: 'loan_due_soon',
          groupId: groupId,
        );
      }
    }
  }

  // --- Reminders (Standard tier+) ---------------------------------------
  //
  // No Cloud Functions/cron on the free plan, so these are secretary-
  // triggered rather than truly scheduled -- an honest simplification,
  // worth naming if asked. Sends an in-app notification to every member
  // who has no ledger entry at all yet.

  Future<int> sendContributionReminders(String groupId) async {
    final group = await _db.collection('njangiGroups').doc(groupId).get();
    final memberIds = List<String>.from(group.data()?['memberIds'] ?? const []);
    final groupName = group.data()?['name'] ?? 'your group';

    final ledgerSnap = await _db.collection('njangiGroups').doc(groupId).collection('ledger').get();
    final contributedIds = ledgerSnap.docs.map((d) => d.data()['memberId'] as String?).toSet();

    final toRemind = memberIds.where((id) => !contributedIds.contains(id)).toList();
    for (final id in toRemind) {
      await _notifications.notify(
        recipientUserId: id,
        title: 'Contribution reminder',
        body: 'Don\'t forget to make your contribution to $groupName.',
        type: 'reminder',
        groupId: groupId,
      );
    }
    return toRemind.length;
  }

  Future<List<AppUser>> groupMembers(String groupId) async {
    final snap = await _db.collection('njangiGroups').doc(groupId).collection('members').get();
    final ids = snap.docs.map((d) => d.id).toList();
    if (ids.isEmpty) return [];
    final users = <AppUser>[];
    for (final id in ids) {
      final doc = await _db.collection('users').doc(id).get();
      if (doc.exists) users.add(AppUser.fromDoc(doc));
    }
    return users;
  }

  // --- Public group discovery + join requests ----------------------------
  //
  // Any signed-in user can see the basic group directory (name, plan,
  // member count) even for groups they're not in -- ledger/loans/members
  // detail stays restricted to actual members via firestore.rules. A join
  // request is a small doc keyed by the requester's own uid so the rules
  // can cleanly say "you can only touch your own request".

  Stream<List<NjangiGroup>> allGroups() {
    return _db
        .collection('njangiGroups')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(NjangiGroup.fromDoc).toList());
  }

  Future<void> requestToJoin(String groupId) {
    return _db
        .collection('njangiGroups')
        .doc(groupId)
        .collection('joinRequests')
        .doc(_uid)
        .set({
      'memberId': _uid,
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<bool> hasPendingJoinRequest(String groupId) {
    return _db
        .collection('njangiGroups')
        .doc(groupId)
        .collection('joinRequests')
        .doc(_uid)
        .snapshots()
        .map((doc) => doc.exists && doc.data()?['status'] == 'pending');
  }

  Stream<List<JoinRequest>> pendingJoinRequests(String groupId) {
    return _db
        .collection('njangiGroups')
        .doc(groupId)
        .collection('joinRequests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map(JoinRequest.fromDoc).toList());
  }

  Future<void> respondToJoinRequest(String groupId, String requesterId, bool accept) async {
    final ref = _db.collection('njangiGroups').doc(groupId).collection('joinRequests').doc(requesterId);
    if (accept) {
      await ref.update({'status': 'accepted'});
      final group = await _db.collection('njangiGroups').doc(groupId).get();
      // addMember() already sends the "you were added" notification.
      await addMember(groupId, requesterId, (group.data()?['memberIds'] as List?)?.length ?? 0);
    } else {
      await ref.update({'status': 'declined'});
      await _notifications.notify(
        recipientUserId: requesterId,
        title: 'Join request declined',
        body: 'Your request to join this group was declined.',
        type: 'join_declined',
        groupId: groupId,
      );
    }
  }

  Future<String> createGroup({
    required String name,
    required int contributionAmount,
    required String meetingSchedule,
    required String momoNumber,
    int socialFundAmount = 0,
  }) async {
    final doc = await _db.collection('njangiGroups').add({
      'name': name,
      'createdBy': _uid,
      'createdAt': FieldValue.serverTimestamp(),
      'planTier': 'free',
      'contributionAmount': contributionAmount,
      'currency': 'XAF',
      'meetingSchedule': meetingSchedule,
      'momoNumber': momoNumber,
      'socialFundAmount': socialFundAmount,
      'rotationOrder': [_uid],
      'currentRotationIndex': 0,
      'memberIds': [_uid],
    });

    await doc.collection('members').doc(_uid).set({
      'userId': _uid,
      'role': 'secretary', // creator is secretary by default
      'joinedAt': FieldValue.serverTimestamp(),
      'status': 'active',
      'rotationPosition': 0,
    });

    await _writeAudit(
      groupId: doc.id,
      action: 'group_created',
      targetId: doc.id,
      after: {'name': name, 'contributionAmount': contributionAmount},
    );

    return doc.id;
  }

  /// Sets planTier after a (fake, for now) MoMo payment confirms.
  Future<void> upgradePlan(String groupId, String previousTier, String newTier) async {
    await _db.collection('njangiGroups').doc(groupId).update({'planTier': newTier});
    await _writeAudit(
      groupId: groupId,
      action: 'plan_upgraded',
      targetId: groupId,
      before: {'planTier': previousTier},
      after: {'planTier': newTier},
    );
  }

  Stream<List<LedgerEntry>> ledger(String groupId) {
    return _db
        .collection('njangiGroups')
        .doc(groupId)
        .collection('ledger')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(LedgerEntry.fromDoc).toList());
  }

  /// Live role of the signed-in user within this group, so screens can
  /// show/hide secretary-only actions (like approving entries) for real
  /// instead of trusting a hardcoded flag. Firestore rules are still the
  /// real enforcement -- this is just for UI.
  Stream<String?> myRole(String groupId) {
    return _db
        .collection('njangiGroups')
        .doc(groupId)
        .collection('members')
        .doc(_uid)
        .snapshots()
        .map((doc) => doc.data()?['role'] as String?);
  }

  Stream<List<LedgerEntry>> pendingEntries(String groupId) {
    return _db
        .collection('njangiGroups')
        .doc(groupId)
        .collection('ledger')
        .where('status', isEqualTo: 'pending')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(LedgerEntry.fromDoc).toList());
  }

  /// Secretary approves or flags a pending entry. Firestore rules already
  /// restrict this update to the secretary role -- see firestore.rules.
  /// Reads the entry first so the audit log can record the real
  /// before/after status, per the SRS requirement: WHO changed WHAT, WHEN.
  Future<void> setEntryStatus(String groupId, String entryId, String status) async {
    final ref = _db.collection('njangiGroups').doc(groupId).collection('ledger').doc(entryId);
    final before = await ref.get();
    final previousStatus = before.data()?['status'] as String? ?? 'unknown';
    final memberId = before.data()?['memberId'] as String?;
    final amount = before.data()?['amount'];
    final type = before.data()?['type'] as String?;
    final loanId = before.data()?['loanId'] as String?;

    await ref.update({'status': status});

    // A loan repayment only actually reduces the loan's outstanding
    // balance once the secretary verifies it -- matches how a
    // contribution doesn't count toward the group balance while pending.
    if (type == 'loanRepayment' && loanId != null && status == 'verified' && amount is int) {
      final loanRef = _db.collection('njangiGroups').doc(groupId).collection('loans').doc(loanId);
      final loanDoc = await loanRef.get();
      final outstanding = (loanDoc.data()?['outstandingBalance'] ?? 0) as int;
      final newOutstanding = (outstanding - amount).clamp(0, outstanding);
      await loanRef.update({
        'outstandingBalance': newOutstanding,
        if (newOutstanding == 0) 'status': 'repaid',
      });
    }

    await _writeAudit(
      groupId: groupId,
      action: 'ledger_entry_status_changed',
      targetId: entryId,
      before: {'status': previousStatus},
      after: {'status': status},
    );

    // Let the member who submitted this entry know -- but not if they're
    // the one who acted on their own entry (edge case, shouldn't normally
    // happen since only the secretary can call this).
    if (memberId != null && memberId != _uid) {
      final group = await _db.collection('njangiGroups').doc(groupId).get();
      final groupName = group.data()?['name'] ?? 'your group';
      if (status == 'verified') {
        await _notifications.notify(
          recipientUserId: memberId,
          title: 'Contribution verified',
          body: 'Your $amount XAF contribution to $groupName was verified.',
          type: 'ledger_verified',
          groupId: groupId,
        );
      } else if (status == 'flagged') {
        await _notifications.notify(
          recipientUserId: memberId,
          title: 'Contribution flagged',
          body: 'Your $amount XAF contribution to $groupName was flagged for review. Contact your secretary.',
          type: 'ledger_flagged',
          groupId: groupId,
        );
      }
    }
  }

  Future<String?> memberName(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return doc.data()?['name'] as String?;
  }

  /// If [onBehalfOfMemberId] is set, the ledger entry is credited to that
  /// member (they're the one who "made" the contribution as far as the
  /// group's records show) while `recordedBy` still shows who actually
  /// submitted it -- covers a member without a phone having someone else
  /// pay and submit on their behalf, without losing who really paid.
  Future<void> addLedgerEntry({
    required String groupId,
    required String type,
    required int amount,
    String? sourceScreenshotUrl,
    Map<String, dynamic>? ocrExtracted,
    String? onBehalfOfMemberId,
  }) async {
    final creditedMember = onBehalfOfMemberId ?? _uid;
    final doc = await _db.collection('njangiGroups').doc(groupId).collection('ledger').add({
      'type': type,
      'memberId': creditedMember,
      'amount': amount,
      'date': FieldValue.serverTimestamp(),
      'recordedBy': _uid,
      'status': 'pending',
      if (onBehalfOfMemberId != null) 'paidBy': _uid,
      if (sourceScreenshotUrl != null) 'sourceScreenshotUrl': sourceScreenshotUrl,
      if (ocrExtracted != null) 'ocrExtracted': ocrExtracted,
    });

    await _writeAudit(
      groupId: groupId,
      action: 'ledger_entry_created',
      targetId: doc.id,
      after: {'type': type, 'amount': amount, 'status': 'pending'},
    );
  }

  // --- Audit trail -----------------------------------------------------
  //
  // No Cloud Functions on the free Spark plan, so this is written directly
  // from the client rather than by a server-side trigger. It's append-only
  // (firestore.rules blocks update/delete entirely) and every entry
  // records who made it, what changed, and when -- satisfying the SRS's
  // "no silent modification" requirement, just enforced by rules instead
  // of by a trusted server function. Worth naming as a known tradeoff if
  // asked about it in your presentation.

  Future<void> _writeAudit({
    required String groupId,
    required String action,
    required String targetId,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) {
    return _db.collection('njangiGroups').doc(groupId).collection('auditLog').add({
      'action': action,
      'performedBy': _uid,
      'targetId': targetId,
      'timestamp': FieldValue.serverTimestamp(),
      if (before != null) 'before': before,
      if (after != null) 'after': after,
    });
  }

  Stream<List<AuditLogEntry>> auditLog(String groupId) {
    return _db
        .collection('njangiGroups')
        .doc(groupId)
        .collection('auditLog')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(AuditLogEntry.fromDoc).toList());
  }
}

class LoanEntry {
  final String id;
  final String memberId;
  final int amount;
  final String status;
  final int outstandingBalance;
  final DateTime? requestedAt;
  final DateTime? dueDate;
  final String? collateral;
  final String momoNumber;
  final bool lateFeeApplied;

  LoanEntry({
    required this.id,
    required this.memberId,
    required this.amount,
    required this.status,
    required this.outstandingBalance,
    required this.requestedAt,
    this.dueDate,
    this.collateral,
    this.momoNumber = '',
    this.lateFeeApplied = false,
  });

  bool get isOverdue =>
      status == 'active' && dueDate != null && DateTime.now().isAfter(dueDate!);

  factory LoanEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return LoanEntry(
      id: doc.id,
      memberId: d['memberId'] ?? '',
      amount: (d['amount'] ?? 0) as int,
      status: d['status'] ?? 'requested',
      outstandingBalance: (d['outstandingBalance'] ?? 0) as int,
      requestedAt: (d['requestedAt'] as Timestamp?)?.toDate(),
      dueDate: (d['dueDate'] as Timestamp?)?.toDate(),
      collateral: d['collateral'],
      momoNumber: d['momoNumber'] ?? '',
      lateFeeApplied: d['lateFeeApplied'] ?? false,
    );
  }
}

class JoinRequest {
  final String memberId;
  final String status;
  final DateTime? requestedAt;

  JoinRequest({required this.memberId, required this.status, required this.requestedAt});

  factory JoinRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return JoinRequest(
      memberId: d['memberId'] ?? doc.id,
      status: d['status'] ?? 'pending',
      requestedAt: (d['requestedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class AppUser {
  final String id;
  final String name;
  final String email;

  AppUser({required this.id, required this.name, required this.email});

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AppUser(
      id: doc.id,
      name: d['name'] ?? '',
      email: d['email'] ?? '',
    );
  }
}

class NjangiGroup {
  final String id;
  final String name;
  final String planTier;
  final int contributionAmount;
  final String currency;
  final String meetingSchedule;
  final String momoNumber;
  final List<String> memberIds;
  final List<String> rotationOrder;
  final int currentRotationIndex;

  NjangiGroup({
    required this.id,
    required this.name,
    required this.planTier,
    required this.contributionAmount,
    required this.currency,
    required this.meetingSchedule,
    required this.momoNumber,
    required this.memberIds,
    required this.rotationOrder,
    required this.currentRotationIndex,
  });

  factory NjangiGroup.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return NjangiGroup(
      id: doc.id,
      name: d['name'] ?? '',
      planTier: d['planTier'] ?? 'free',
      contributionAmount: (d['contributionAmount'] ?? 0) as int,
      currency: d['currency'] ?? 'XAF',
      meetingSchedule: d['meetingSchedule'] ?? '',
      momoNumber: d['momoNumber'] ?? '',
      memberIds: List<String>.from(d['memberIds'] ?? const []),
      rotationOrder: List<String>.from(d['rotationOrder'] ?? const []),
      currentRotationIndex: (d['currentRotationIndex'] ?? 0) as int,
    );
  }
}

class LedgerEntry {
  final String id;
  final String type;
  final String memberId;
  final int amount;
  final String status;
  final DateTime? date;
  final String? sourceScreenshotUrl;
  final Map<String, dynamic>? ocrExtracted;
  final String? loanId;
  final String? paidBy;

  LedgerEntry({
    required this.id,
    required this.type,
    required this.memberId,
    required this.amount,
    required this.status,
    required this.date,
    this.sourceScreenshotUrl,
    this.ocrExtracted,
    this.loanId,
    this.paidBy,
  });

  factory LedgerEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return LedgerEntry(
      id: doc.id,
      type: d['type'] ?? '',
      memberId: d['memberId'] ?? '',
      amount: (d['amount'] ?? 0) as int,
      status: d['status'] ?? 'pending',
      date: (d['date'] as Timestamp?)?.toDate(),
      sourceScreenshotUrl: d['sourceScreenshotUrl'],
      ocrExtracted: d['ocrExtracted'],
      loanId: d['loanId'],
      paidBy: d['paidBy'],
    );
  }
}

class AuditLogEntry {
  final String id;
  final String action;
  final String performedBy;
  final String targetId;
  final DateTime? timestamp;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;

  AuditLogEntry({
    required this.id,
    required this.action,
    required this.performedBy,
    required this.targetId,
    required this.timestamp,
    this.before,
    this.after,
  });

  factory AuditLogEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AuditLogEntry(
      id: doc.id,
      action: d['action'] ?? '',
      performedBy: d['performedBy'] ?? '',
      targetId: d['targetId'] ?? '',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate(),
      before: d['before'] != null ? Map<String, dynamic>.from(d['before']) : null,
      after: d['after'] != null ? Map<String, dynamic>.from(d['after']) : null,
    );
  }
}