import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const _bodyStyle = TextStyle(fontSize: 14, height: 1.5);
  static const _headingStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        title: Text(ParentLocalizations.of(context).privacyPolicy),
        bottom: IcueContextBar(
          label: context.watch<ParentAuthProvider>().selectedStudent?.name,
        ),
      ),
      body: IcueSheetBody(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: const [
            // INTRODUCTION
            Text('INTRODUCTION', style: _headingStyle),
            SizedBox(height: 8),
            Text(
              'Thoughtniques Technologies Private Limited (“Thoughtniques” / “Company” / “we” / '
              '“us” / “our”) respects the privacy of all the users (“User” / “you” / “your”) who use '
              'and access its web portal thoughtniques.com for availing the Services in its website '
              'portal thoughtniques.com (“Website Portal”) for providing Services in any other '
              'capacity on behalf of our clients. The Company is committed towards protecting and '
              'safeguarding the personal information of its Users which may be collected by Thoughtniques '
              'in the provision of the Services or in consequence of your use or access of the Application '
              'and / or the Website Portal. Any Personal Information collected from You on the Application '
              'and / or the Website Portal shall be governed by this privacy policy (“Privacy Policy”). '
              'This Privacy Policy provides for the kind of personal information collected on the Website '
              'Portal, use of such information, disclosure and handling of such information by Thoughtniques. '
              'The Users are advised to read the Privacy Policy, along with the Company’s Terms of Use, '
              'before using the Website Portal or availing the Services and providing Thoughtniques with '
              'their Personal Information.\n\n'
              'By using or accessing the Website Portal or availing the Services, you signify your consent '
              'for Thoughtniques to collect and manage your Personal Information in accordance with this '
              'Privacy Policy. If you do not agree with any aspects of this Privacy Policy, then you shall '
              'not be authorized to use or access the Website Portal in any manner.\n\n'
              'This Privacy Policy is published in compliance with:\n'
              '• Section 43A of the Information Technology Act, 2000;\n'
              '• Rule 4 of the Information Technology (Reasonable Security Practices and Processes and '
              'Sensitive Personal Data or Information) Rules, 2011; and\n'
              '• Rule 3(1) of the Information Technology (Intermediaries Guidelines) Rules, 2011.',
              style: _bodyStyle,
            ),
            SizedBox(height: 24),

            // Section 1
            Text('1. GENERAL', style: _headingStyle),
            SizedBox(height: 8),
            Text(
              'By using or accessing the Website Portal or by otherwise giving us your Information '
              'through physical or other means, you confirm that you have the capacity to enter into a '
              'legally binding contract and that you have read, understood and agreed to the practices '
              'and policies outlined in this Privacy Policy and our Terms of Use (together the “Agreement”). '
              'You hereby consent to our collection, use, sharing, and disclosure of your Information as '
              'described in this Privacy Policy.\n\n'
              'The collection and processing of Information in the course of other contractual or commercial '
              'engagements that we may enter into with you, will be done in accordance with the specific terms '
              'applicable thereto, and not by this Privacy Policy.',
              style: _bodyStyle,
            ),
            SizedBox(height: 24),

            // Section 2
            Text('2. INFORMATION BEING COLLECTED', style: _headingStyle),
            SizedBox(height: 8),
            Text(
              'You can access / use the Application and / or the Website Portal by registering an account '
              ' (“Account”) and providing your personal data / information. When a User: (i) registers an '
              'Account or communicates, in any manner, with Thoughtniques or its employees, agents / '
              'representatives, or with service providers, we may collect and store all or any Information '
              'that can be used to identify you, including sensitive personal data and other non-personal '
              'information. The Information being collected may vary depending upon your use of the '
              'Application, the Website Portal or any Service.\n\n'
              'The following information may be collected by the Company (“Information”):\n\n'
              '• Your full name, contact details, email address, financial information (credit card / debit '
              'card number, expiration date, CVV number, banking details, etc.), official identifier, '
              'biometric data, genetic data, caste / tribe and any other related information / data (“Personal '
              'Information”).\n'
              '• Transaction related information such as billing information, payment history, etc. in '
              'relation to your facility booking or any Service or purchase of any other related products or '
              'service, or purchase Services in lieu of any offers or otherwise on a discount;\n'
              '• Account related information such as username and password, and other security-related '
              'information used by you in relation to your Account;\n'
              '• We may also collect information about how you use the Application and / or the Website '
              'Portal and the Services;\n'
              '• Information about your mobile / tablet or other device, software including usage statistics, '
              'traffic data, your IP address, network provider, internet browser details, operating system '
              'type, domain names, access times, locations, and details regarding the parts of the Platform '
              'that you access;\n'
              '• We also store cookies to: (i) track user activity, behavior and movement on the Website '
              'Portal; (ii) analyze user patterns and trends; (iii) track the sections, links, tabs or pages '
              'that are most visited by the users; and (iv) to build a database of user preferences (“Cookies”);\n'
              '• Technical data / information recorded automatically through Cookies, log files and other '
              'similar web technologies;\n'
              '• Information provided by you while contacting us for help or raising any questions or grievances; and\n'
              '• Any other information or details collected during the provision of the Service.',
              style: _bodyStyle,
            ),
            SizedBox(height: 24),

            // Section 3
            Text('3. CONSENT', style: _headingStyle),
            SizedBox(height: 8),
            Text(
              'By using / accessing the Application and / or the Website Portal or availing the Services in '
              'any other manner (including but not limited to facility booking physically), you acknowledge '
              'and agree that all Information, including Personal Information, provided by you to us is '
              'voluntary which can be used in accordance with this Privacy Policy. The collection, use and '
              'disclosure of Personal Information requires your express consent, unless there are other legal '
              'grounds available to us to collect such information as further specified in this Privacy Policy. '
              'By using or accessing the Application and / or the Website Portal or availing the Services or '
              'otherwise providing us with your Personal Information, where applicable, you are providing us '
              'with your unconditional consent to our collection, usage, disclosure and retention of the '
              'Personal Information in accordance with the terms of this Privacy Policy.\n\n'
              'In the event of a change in the law applicable to data protection in India, you hereby '
              'expressly consent to our continued use, storage, collection and disclosure of your Information, '
              'including Personal Information, to the fullest extent permitted under such applicable law. We '
              'may reach out to you for obtaining additional consents and approvals as required under the '
              'amended law and you will be required to comply with such requests. Should you choose to not '
              'provide us with such additional consents and approvals, we may have to discontinue your access '
              'to or use of the Application and / or the Website Portal and your Account.\n\n'
              'You may choose to withdraw your consent by writing to Thoughtniques at support@thoughtniques.com. '
              'However, such withdrawal of consent will result in discontinuation of your Account and access '
              'to the Application and / or the Website Portal, along with discontinuation of the Services for '
              'which such Personal Information is required.',
              style: _bodyStyle,
            ),
            SizedBox(height: 24),

            // Section 4
            Text('4. USE OF INFORMATION', style: _headingStyle),
            SizedBox(height: 8),
            Text(
              'Thoughtniques collects Information, specifically your Personal Information for the primary '
              'purpose of providing efficient and customized services to the Users. Such Personal Information '
              'allows Thoughtniques to provide personalized services to the Users thereby improving and enhancing '
              'the user experience.',
              style: _bodyStyle,
            ),
            SizedBox(height: 24),

            // Section 5
            Text('5. YOUR RIGHTS', style: _headingStyle),
            SizedBox(height: 8),
            Text(
              'You may access and review your Personal Information from your Account. You have the right to '
              'rectify or correct any inaccuracies in relation to your Personal Information, update any out of '
              'date or inaccurate information, or delete such information (except mandatory fields) from your '
              'Account directly.',
              style: _bodyStyle,
            ),
            SizedBox(height: 24),

            // Section 6
            Text('6. RETENTION OF INFORMATION', style: _headingStyle),
            SizedBox(height: 8),
            Text(
              'We retain your Information, including Personal Information on our servers for as long as your '
              'Account is active or as needed to provide you with Services that you request, or as is reasonably '
              'necessary for the purposes listed in this Privacy Policy. In some circumstances we may retain your '
              'Personal Information for longer periods of time, for instance where we are required to do so in '
              'accordance with any legal, regulatory, tax or accounting requirements. Where your Information or '
              'Personal Information is no longer required, we will ensure it is either deleted or securely stored '
              'in an anonymized manner.',
              style: _bodyStyle,
            ),
            SizedBox(height: 24),

            // Section 7
            Text('7. DISCLOSURE', style: _headingStyle),
            SizedBox(height: 8),
            Text(
              'Thoughtniques does not disclose any Personal Information to any individual or entity except as '
              'provided in this Privacy Policy. Thoughtniques may disclose such Personal Information only when '
              'required under an applicable law to any authority authorized to collect such information and only '
              'to the extent necessary. Thoughtniques may at its sole discretion, disclose the Personal Information '
              'of its Users to:\n\n'
              '• Its employees, agents, representatives, Service Providers and third party vendors who need to '
              'know such Information, including Personal Information in order to process it for us, and who are '
              'subject to strict contractual confidentiality obligations; and\n'
              '• Third party organizations / entities who may analyze such Information and other related data for '
              'the purpose of developing new services or products, enhancing and improving its Services, '
              'conducting research, marketing of the Application and/or the Website Portal, the Services or other '
              'products or services and other related purposes. Thoughtniques does not sell or trade in any form '
              'or manner, the Information or Personal Information of its Users to any third party.\n\n'
              'In the event that Thoughtniques discloses the Personal Information of its Users to any third party, '
              'it ensures that such third party is bound by confidentiality obligations similar to the confidentiality '
              'obligations of Thoughtniques under this Privacy Policy, prior to such disclosure to such third party.',
              style: _bodyStyle,
            ),
            SizedBox(height: 24),

            // Section 8
            Text('8. SECURITY', style: _headingStyle),
            SizedBox(height: 8),
            Text(
              'We are committed to ensure that your Personal Information is secure with us. To ensure the security '
              'and protection from any unauthorized access or disclosure we have in place appropriate physical, '
              'electronic and managerial procedures to safeguard and secure the Personal Information we collect on '
              'the Application and the Website Portal. We do not retain any Personal Information collected from you '
              'for any period longer than reasonably required by us for the purpose of our Services or such period '
              'as may be required by applicable laws in India. However, please be informed that despite the stringent '
              'security measures being adopted by Thoughtniques, there may still exist the risk of potential '
              'security breaches. Further, we shall not be responsible for any breach of security or for any actions '
              'of any third parties or events that are beyond our reasonable control, including but not limited to, '
              'acts of government, hacking of devices, unauthorized access to data or other electronic devices and '
              'storage devices, device crashes, breach of security and encryption, etc.',
              style: _bodyStyle,
            ),
            SizedBox(height: 24),

            // Section 9
            Text('9. CHANGE IN PRIVACY POLICY', style: _headingStyle),
            SizedBox(height: 8),
            Text(
              'Thoughtniques is committed to comply with the extant applicable laws of India. Thoughtniques reserves '
              'the right to amend, modify, add, delete or remove any portion of this Privacy Policy as may be required '
              'under any applicable law or if required to enhance and improve the Users’ experience of its '
              'Application and/or the Website Portal. Usage of your Information, including Personal Information, shall '
              'be governed by the last updated or revised Privacy Policy which shall be available on the Application '
              'and Website Portal. Your continued use/access/browsing of the Application and/or the Website Portal after '
              'any such amendment or modification signifies your acceptance to such amendment or modification. If you '
              'do not agree with this Privacy Policy at any time, in part or as a whole, you must not use/access/browse '
              'the Application and/or the Website Portal.',
              style: _bodyStyle,
            ),
            SizedBox(height: 24),

            // Section 10
            Text('10. DISCLAIMER', style: _headingStyle),
            SizedBox(height: 8),
            Text(
              'Although we are committed to protecting your privacy, we do not make any promise to the effect that your '
              'Information, including Personal Information, or private communications will always remain private or may '
              'be disclosed in ways not otherwise described in this Privacy Policy. You assume all responsibility and '
              'risk for: (i) your use of the Application and/or the Website Portal; (ii) use of the internet generally; '
              '(iii) the information you provide to us; and (iv) your conduct on and off the Application and the Website '
              'Portal. Further, we assume no liability for any actions of third parties with regard to your Information or '
              'Personal Information which you may have disclosed to such third parties by accessing or visiting platforms of '
              'such third parties. Thoughtniques shall disclaim any liability arising out of your disclosure of Personal '
              'Information to or any other dealings with any third parties or generally in your use, access or browsing of '
              'the internet or internet-based platforms.',
              style: _bodyStyle,
            ),
            SizedBox(height: 24),

            // Section 11
            Text('11. GOVERNING LAW', style: _headingStyle),
            SizedBox(height: 8),
            Text(
              'This Privacy Policy shall, in all respects, be governed by and construed in all respect in accordance '
              'with the laws of India. Thoughtniques and the User agree to submit to the exclusive jurisdiction of the '
              'courts in Hyderabad in connection with any dispute arising out of or in connection with this Privacy Policy.\n\n'
              'If you have questions, comments or suggestions about this Privacy Policy or practices of Thoughtniques, '
              'please send Thoughtniques an e-mail at support@thoughtniques.com.',
              style: _bodyStyle,
            ),
            SizedBox(height: 24),

            // Section 12
            Text('12. GRIEVANCE REDRESSAL', style: _headingStyle),
            SizedBox(height: 8),
            Text(
              'If you have questions, comments, suggestions or grievances with respect to the Privacy Policy, please send us an e-mail at support@thoughtniques.com.',
              style: _bodyStyle,
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
