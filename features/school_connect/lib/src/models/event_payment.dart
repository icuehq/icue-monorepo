class QuestionAnswer {
  const QuestionAnswer({
    required this.id,
    required this.question,
    required this.answer,
  });

  factory QuestionAnswer.fromJson(Map<String, dynamic> json) => QuestionAnswer(
    id: (json['Id'] as num).toInt(),
    question: json['Qns'] as String? ?? '',
    answer: '${json['Ans']}',
  );

  final int id;
  final String question;
  final String answer;
}

class EventBooking {
  const EventBooking({
    required this.attendDate,
    required this.booked,
    required this.attended,
    required this.totalPrice,
    required this.answers,
  });

  factory EventBooking.fromJson(Map<String, dynamic> json) => EventBooking(
    attendDate: json['AttendDate'] as String? ?? '',
    booked: (json['NoOfPersonAttend'] as num?)?.toInt() ?? 0,
    attended: (json['NoOfPersonAttended'] as num?)?.toInt() ?? 0,
    totalPrice: json['TotalPrice'] as num? ?? 0,
    answers: (json['CustomQnsAns'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => QuestionAnswer.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final String attendDate;
  final int booked;
  final int attended;
  final num totalPrice;
  final List<QuestionAnswer> answers;
}

class EventPayment {
  const EventPayment({
    required this.id,
    required this.eventName,
    required this.status,
    required this.amount,
    required this.subAmount,
    required this.convenienceFee,
    required this.paymentDate,
    required this.paymentTime,
    required this.bookings,
    required this.studentNames,
  });

  factory EventPayment.fromJson(Map<String, dynamic> json) => EventPayment(
    id: (json['Id'] as num).toInt(),
    eventName: json['EventName'] as String? ?? '',
    status: json['PaymentStatus'] as String? ?? '',
    amount: json['Amount'] as num? ?? 0,
    subAmount: json['SubAmount'] as num? ?? 0,
    convenienceFee: json['ConvenienceFee'] as num? ?? 0,
    paymentDate: json['PaymentDate'] as String? ?? '',
    paymentTime: json['PaymentTime'] as String? ?? '',
    bookings: (json['Events'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => EventBooking.fromJson(e as Map<String, dynamic>))
        .toList(),
    studentNames: (json['StuNames'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => '$e')
        .toList(),
  );

  final int id;
  final String eventName;

  /// `Completed`, `Failed` or `Initiated`.
  final String status;
  final num amount;
  final num subAmount;
  final num convenienceFee;
  final String paymentDate;
  final String paymentTime;
  final List<EventBooking> bookings;
  final List<String> studentNames;
}

/// One page of payments with the total count for "load more".
class EventPaymentPage {
  const EventPaymentPage({required this.payments, required this.total});

  factory EventPaymentPage.fromJson(Map<String, dynamic> json) =>
      EventPaymentPage(
        payments: (json['data'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => EventPayment.fromJson(e as Map<String, dynamic>))
            .toList(),
        total:
            ((json['metadata'] as Map<String, dynamic>?)?['total'] as num?)
                ?.toInt() ??
            0,
      );

  final List<EventPayment> payments;
  final int total;
}
