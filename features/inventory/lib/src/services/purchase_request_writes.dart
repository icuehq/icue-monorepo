import 'package:icue_firebase/icue_firebase.dart';
import 'package:inventory/src/services/procurement_support.dart';

/// Purchase requests: save, submit, decide, cancel.
class PurchaseRequestWrites with ProcurementSupport {
  Future<Map<String, dynamic>> savePurchaseRequest(
    Map<String, Object?> data,
  ) async {
    final requiredDate = data['requiredDate']! as String;
    if (requiredDate.compareTo(todayDay) < 0) {
      failWith('Required date is in the past');
    }
    final submit = data['submit'] == true;
    final lines = asLines(data['lineItems']);
    if (lines.isEmpty) failWith('Add at least one item');
    requireUniqueLines(lines);
    final storedLines = [
      for (final line in lines)
        {
          'itemId': line['itemId'],
          'variantId': line['variantId'],
          'quantity': line['quantity'],
          'estimatedPrice': line['estimatedPrice'] ?? 0,
        },
    ];
    final fields = {
      'requiredDate': dayTimestamp(requiredDate),
      'priority': data['priority'] ?? 'normal',
      'purpose': (data['purpose']! as String).trim(),
      'remarks': blankToNullText(data['remarks']),
      'lineItems': storedLines,
      'itemIds': {for (final line in storedLines) line['itemId']}.toList(),
      'total': roundToCents(
        storedLines.fold<double>(
          0,
          (total, line) =>
              total +
              (line['quantity']! as num) * (line['estimatedPrice']! as num),
        ),
      ),
    };
    final id = data['id'] as String?;
    if (id != null) {
      final (:reference, data: existing) = await loadDocument(
        'inventoryPurchaseRequests',
        id,
        'Purchase request',
      );
      _requireOwnDraft(existing);
      final history = [
        ...(existing['history'] as List? ?? []),
        if (submit) historyEntry('submit'),
      ];
      await reference.update({
        ...fields,
        if (submit) 'status': 'pending',
        'history': history,
        'lastWrite': writeStamp(
          submit
              ? 'inventoryPurchaseRequest.submit'
              : 'inventoryPurchaseRequest.update',
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return {'id': id, 'number': existing['number']};
    }
    final number = await nextNumber('PR');
    final collection = await branchCollection('inventoryPurchaseRequests');
    final reference = collection.doc();
    final access = await (await branchCollection('userAccess'))
        .doc(currentUid)
        .get();
    await reference.set({
      ...fields,
      'number': number,
      'requestedBy': access.data()?['personErpId'],
      'attachments': <Object?>[],
      'approval': null,
      'status': submit ? 'pending' : 'draft',
      'history': [if (submit) historyEntry('submit')],
      'requestedDate': dayTimestamp(todayDay),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': currentUid,
      'lastWrite': writeStamp(
        submit
            ? 'inventoryPurchaseRequest.submit'
            : 'inventoryPurchaseRequest.create',
      ),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return {'id': reference.id, 'number': number};
  }

  void _requireOwnDraft(Map<String, dynamic> request) {
    if (request['createdBy'] != currentUid) {
      failWith('Only the requester can change this request');
    }
    if (!editablePurchaseRequestStatuses.contains(request['status'])) {
      failWith('Request is ${request['status']}');
    }
  }

  Future<Map<String, dynamic>> submitPurchaseRequest(
    Map<String, Object?> data,
  ) async {
    final (:reference, data: request) = await loadDocument(
      'inventoryPurchaseRequests',
      data['id']! as String,
      'Purchase request',
    );
    _requireOwnDraft(request);
    await reference.update({
      'status': 'pending',
      'history': [...(request['history'] as List), historyEntry('submit')],
      'lastWrite': writeStamp('inventoryPurchaseRequest.submit'),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return {'id': reference.id, 'number': request['number']};
  }

  Future<Map<String, dynamic>> decidePurchaseRequest(
    Map<String, Object?> data,
  ) async {
    final (:reference, data: request) = await loadDocument(
      'inventoryPurchaseRequests',
      data['id']! as String,
      'Purchase request',
    );
    if (request['status'] != 'pending') {
      failWith('Request is ${request['status']}');
    }
    final decision = data['decision']! as String;
    final comment = blankToNullText(data['comment']);
    if (decision != 'approve' && comment == null) {
      failWith('A comment is required');
    }
    await reference.update({
      'status': switch (decision) {
        'approve' => 'approved',
        'reject' => 'rejected',
        _ => 'revision_requested',
      },
      'history': [
        ...(request['history'] as List),
        historyEntry(decision, comment),
      ],
      'approval': {
        'performedBy': currentUid,
        'performedAt': FieldValue.serverTimestamp(),
        'decision': decision,
        'comment': comment,
      },
      'lastWrite': writeStamp('inventoryPurchaseRequest.$decision', comment),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return {'id': reference.id, 'number': request['number']};
  }

  Future<Map<String, dynamic>> cancelPurchaseRequest(
    Map<String, Object?> data,
  ) async {
    final (:reference, data: request) = await loadDocument(
      'inventoryPurchaseRequests',
      data['id']! as String,
      'Purchase request',
    );
    if (request['createdBy'] != currentUid) {
      failWith('Only the requester can cancel this request');
    }
    if (!cancellablePurchaseRequestStatuses.contains(request['status'])) {
      failWith('Request is ${request['status']}');
    }
    await reference.update({
      'status': 'cancelled',
      'history': [
        ...(request['history'] as List),
        historyEntry('cancel', blankToNullText(data['reason'])),
      ],
      'lastWrite': writeStamp(
        'inventoryPurchaseRequest.cancel',
        blankToNullText(data['reason']),
      ),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return {'id': reference.id, 'number': request['number']};
  }
}
