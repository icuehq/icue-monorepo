import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/gatepass_provider.dart';
import '../../utils/app_utils.dart';
import '../../widgets/inputfield.dart';
import '../../widgets/no_data_widget.dart';

class PendingGatePassPage extends StatefulWidget {
  const PendingGatePassPage({super.key});

  @override
  State<PendingGatePassPage> createState() => _PendingGatePassPageState();
}

class _PendingGatePassPageState extends State<PendingGatePassPage> {
  DateTime? date;
  final TextEditingController dateController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GatePassProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gate Pass Requests'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: InputField(
              label: 'Date',
              showTitle: false,
              hintText: 'Select Date',
              initialValue: dateController.text,
              controller: dateController,
              type: TextFieldType.datePicker,
              onTap: () async {
                date = await AppUtils.selectDate(
                  context: context,
                  initialDate: date,
                );
                if (date != null) {
                  dateController.text = date.formattedDate();
                  await provider.getGatePassRequests(
                    date.formattedGatePassDate()!,
                  );
                }
              },
            ),
          ),
        ),
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : provider.requests.isEmpty
          ? NoDataWidget(
              msg: date == null
                  ? 'Please select the date'
                  : 'No Gate Pass requests for the selected date!',
            )
          : ListView.separated(
              shrinkWrap: true,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final item = provider.requests[index];
                return Card(
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  color: Colors.white,
                  surfaceTintColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0XFFDEDEDE)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                text: item.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Colors.black,
                                ),
                                children: [
                                  TextSpan(
                                    text: ' (${item.personType})',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(item.gatePassType),
                            const SizedBox(height: 10),
                            Text(
                              '${item.requestDt.formatAsIndianDate(fallback: '')} ${item.requestTime.formatAsIndianTime(fallback: '')}',
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                shape: const RoundedRectangleBorder(),
                                backgroundColor: const Color(0XFFF43C3C),
                              ),
                              onPressed: () async {
                                await provider.updateGatePassStatus(
                                  context: context,
                                  id: item.id,
                                  personId: item.personId,
                                  date: item.requestDate,
                                  status: 'REJECT',
                                );
                                await provider.getGatePassRequests(
                                  item.requestDate,
                                );
                              },
                              label: const Text('Reject'),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                shape: const RoundedRectangleBorder(),
                              ),
                              onPressed: () async {
                                await provider.updateGatePassStatus(
                                  context: context,
                                  id: item.id,
                                  personId: item.personId,
                                  date: item.requestDate,
                                  status: 'APPROVE',
                                );
                                await provider.getGatePassRequests(
                                  item.requestDate,
                                );
                              },
                              label: const Text('Approve'),
                              icon: const Icon(Icons.check),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemCount: provider.requests.length,
            ),
    );
  }
}
