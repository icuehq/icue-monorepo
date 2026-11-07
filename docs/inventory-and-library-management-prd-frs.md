# School ERP – Inventory & Library Management

## Product Requirements Document (PRD) + Functional Requirements Specification (FRS)

**Document Version:** 1.0  
**Requirements Baseline:** 1.1  
**Status:** Functional requirements draft for review and approval  
**Target Platform:** Flutter Web + Flutter Mobile  
**Backend:** Firebase  
**Authentication:** Existing Node.js authentication system  
**Modules:** Inventory Management and Library Management

---

## DOCUMENT CONTROL

## 1. Purpose

This document defines the complete product and functional requirements for two independent modules within the School ERP:

1. Inventory Management
2. Library Management

The objective is to build comprehensive, configurable and maintainable solutions suitable for small, medium and large schools.

The modules must support multiple campuses, different operational requirements, configurable approval processes, historical records and integration with existing ERP functionality.

This document is the functional source of truth for subsequent UI/UX design, technical architecture, development and testing.

## 2. Product principles

The implementation must follow these principles:

1. Keep Inventory and Library independent.
2. Reuse existing school, campus, student and staff records.
3. Avoid duplicate authentication and user management.
4. Prefer straightforward workflows over complex workflow engines.
5. Provide configuration instead of school-specific custom development.
6. Maintain complete transaction and audit history.
7. Make administrative operations efficient on desktop.
8. Optimize scanning and operational activities for mobile.
9. Enforce permissions at the backend level.
10. Avoid unnecessary third-party dependencies and infrastructure.

## 3. Confirmed product decisions

| Requirement | Approved decision |
| --- | --- |
| Institution type | K–12 schools only |
| Colleges/universities | Excluded |
| Module independence | Inventory and Library are independent |
| Inventory categories | All approved categories, including food, medicines, uniforms, books and vehicle spare parts |
| Inventory procurement | Complete procurement lifecycle |
| Inventory tracking | Quantity, batch and individual asset tracking |
| Storage | Multiple campuses, stores, departments and locations |
| Stock issuance | Approval required |
| Purchase requests | Approval required |
| Approval hierarchy | Single approval |
| Asset assignment | Staff and students supported |
| Library type | Physical library initially |
| Number of libraries | Multiple libraries per school |
| Library members | Students and teachers |
| Borrowing policies | Configurable per library and member category |
| Fines | All approved fine types supported |
| Inter-library transfers | Supported |
| Excel/CSV import | Both modules |
| Historical records | Retained across academic and financial years |
| Technology | Flutter + Firebase |
| Authentication | Existing Node.js login |
| International localization | Deferred |

---

## PART A – PRODUCT REQUIREMENTS DOCUMENT (PRD)

## 4. Product overview

## 4.1 Inventory Management

Inventory Management provides schools with a centralized solution to manage materials, supplies, equipment, assets, purchasing, stock distribution and maintenance.

It should answer:

- What items does the school own?
- Where are the items stored?
- How much stock is available?
- Which department or person has received an item?
- What needs to be purchased?
- Which purchases are pending approval?
- Which vendors supply the school?
- Which assets require maintenance?
- Which items are damaged or expired?
- What is the total inventory value?

## 4.2 Library Management

Library Management provides schools with a complete solution to manage physical books, library collections, members, circulation, reservations and fines.

It should answer:

- What books does the school have?
- How many copies are available?
- Where is each book located?
- Who has borrowed a book?
- When is it due?
- Which books are overdue?
- Which books are reserved?
- What fines are outstanding?
- Which books are lost or damaged?
- How actively are students and teachers using the library?

# 5. Product objectives

### Inventory objectives

- Maintain accurate inventory records.
- Eliminate manual stock registers.
- Improve purchasing and procurement visibility.
- Prevent unauthorized stock issuance.
- Track assets throughout their lifecycle.
- Reduce expired, damaged and missing stock.
- Provide campus-wise and school-wide visibility.
- Maintain purchase and vendor history.

### Library objectives

- Digitize physical library operations.
- Maintain an accurate catalogue and accession register.
- Simplify book issue and return.
- Prevent duplicate book issuance.
- Enforce borrowing policies.
- Automate overdue and reservation management.
- Improve visibility into library utilization.
- Provide students and teachers access to their own borrowing information.

# 6. Target users

| User | Primary responsibilities |
| --- | --- |
| School Administrator | Overall module configuration and access |
| Principal | Monitoring, approvals and reports |
| Inventory Manager | Inventory operations |
| Storekeeper | Receiving, stock issuance and verification |
| Procurement Officer | Requests, vendors, quotations and purchase orders |
| Department Head | Requesting and monitoring department supplies |
| Librarian | Catalogue, membership and circulation |
| Teacher | Requesting supplies and viewing personal library records |
| Student | Viewing assigned items and personal library records |

A school may assign multiple responsibilities to one person.

Roles should be configurable using permissions rather than requiring a separate application for each user type.

# 7. Product scope

## 7.1 Inventory scope

| Module | Included functionality |
| --- | --- |
| Item Management | Items, categories, units and tracking |
| Store Management | Campuses, stores and locations |
| Stock Management | Receiving, issuing, returns and transfers |
| Procurement | Requests, approvals and purchasing |
| Vendor Management | Supplier details and history |
| Quotation Management | Multiple quotations and comparison |
| Purchase Orders | Creation, approval status and PDF |
| Goods Receiving | Partial receiving and inspection |
| Invoice Management | Vendor invoice records and payment status |
| Asset Management | Registration, assignment and lifecycle |
| Maintenance | Repairs and servicing |
| Stock Verification | Physical stock audit |
| Notifications | Stock and procurement alerts |
| Reports | Inventory and procurement analytics |

## 7.2 Library scope

| Module | Included functionality |
| --- | --- |
| Library Management | Multiple library locations |
| Catalogue | Book metadata and classification |
| Copy Management | Accession numbers and physical copies |
| Acquisition | Purchases, donations and transfers |
| Membership | Students and teachers |
| Borrowing Policies | Member-specific borrowing rules |
| Circulation | Issue, return and renewal |
| Reservations | Waiting lists and availability |
| Fines | Overdue and replacement charges |
| Lost/Damaged | Book condition and penalties |
| Transfers | Inter-library book transfers |
| Verification | Physical book audit |
| Notifications | Due dates and reservations |
| Reports | Circulation and library analytics |

# 8. Out of scope

The following are explicitly excluded from the initial implementation:

- Digital library and e-book distribution.
- Online academic content subscriptions.
- AI-based book recommendations.
- AI inventory forecasting.
- Automated vendor marketplace.
- Full accounting and payment processing.
- Advanced depreciation accounting.
- Complex multi-level approval engines.
- College and university workflows.
- Country-specific tax and localization engines.
- Separate Inventory or Library mobile applications.

RFID hardware integration should be supported as an integration capability, but should not become a dependency for basic operations.

# 9. Product success criteria

## Inventory

- All stock movements are recorded.
- Available stock cannot become negative through normal operations.
- Approved receiving updates stock correctly.
- Campus-wise stock is visible.
- Procurement status is traceable.
- Assets can be tracked from registration to retirement.
- Stock discrepancies are identifiable.
- Historical transactions remain accessible.

## Library

- Every physical copy has a unique accession number.
- A copy cannot have two active issue transactions.
- Borrowing limits are enforced.
- Due dates are calculated according to the applicable policy.
- Reservation order is maintained.
- Fines are not duplicated.
- Book transfers maintain accurate locations.
- Students and teachers can view their own records.

---

# PART B – FUNCTIONAL REQUIREMENTS SPECIFICATION (FRS)

# 10. Inventory Management – Functional Specification

## 10.1 Inventory Dashboard

**Purpose:** Provide an overview of the school's inventory operations.

### Dashboard information

- Total active inventory items.
- Total available stock.
- Total stock value.
- Low-stock items.
- Out-of-stock items.
- Expiring items.
- Expired items.
- Pending purchase requests.
- Pending approvals.
- Open purchase orders.
- Pending goods receipts.
- Total registered assets.
- Assets under maintenance.

### Filters

- Academic/financial year where relevant.
- Campus.
- Store.
- Item category.
- Date range.

### User actions

- Open item details.
- Open low-stock list.
- View pending approvals.
- View procurement activity.
- Navigate to reports.

### Acceptance criteria

- Dashboard data must respect user permissions.
- Campus-restricted users must not see unauthorized campus data.
- Consolidated school administrators can see all authorized campuses.
- Counts and totals must reflect actual records.

## 10.2 Category Management

**Purpose:** Organize inventory items into categories and subcategories.

### Default categories

1. Stationery.
2. Classroom supplies.
3. Furniture.
4. IT equipment.
5. Laboratory equipment.
6. Sports equipment.
7. Kitchen supplies.
8. Medical supplies.
9. Uniforms.
10. Books for distribution.
11. Cleaning materials.
12. Transport spare parts.
13. Electrical supplies.
14. Maintenance materials.
15. Custom categories.

### Fields

| Field | Required |
| --- | --- |
| Category name | Yes |
| Category code | Yes |
| Description | No |
| Parent category | No |
| Suggested tracking method | Yes |
| Status | Yes |

### Actions

- Create category.
- Edit category.
- Create subcategory.
- Activate/deactivate.
- View associated items.

### Business rules

- Category codes must be unique within the school.
- Categories containing active items cannot be permanently deleted.
- Deactivated categories cannot be used for new items.
- Existing items must retain their category history.

## 10.3 Item Management

**Purpose:** Maintain the master list of all inventory items.

### Item fields

| Field | Required |
| --- | --- |
| Item name | Yes |
| Item code/SKU | Yes |
| Category | Yes |
| Classes (ERP classes, no sections; empty = any class) | No |
| Subcategory | No |
| Description | No |
| Image | No |
| Unit of measurement | Yes |
| Tracking method | Yes |
| Minimum stock level | No |
| Reorder level | No |
| Default purchase price | No |
| Preferred vendor | No |
| Default storage location | No |
| Status | Yes |

### Tracking methods

**Quantity tracking**

Used for stationery, cleaning supplies and general consumables.

**Batch tracking**

Used for food, medicines and other items requiring batch-level tracking.

Additional information:

- Batch number.
- Manufacturing date, where applicable.
- Expiry date, where applicable.
- Quantity received.
- Quantity available.
- Supplier reference.

**Individual asset tracking**

Used for furniture, computers, laboratory equipment and similar items.

Additional information:

- Asset identifier.
- Serial number.
- Model.
- Warranty.
- Purchase information.
- Condition.
- Assignment information.

**Variants**

Uniforms and similar items should support variants such as:

- Size.
- Color.
- Model.
- Other configurable attributes.

### Actions

- Add item.
- Edit item.
- View item.
- Change category.
- Update reorder levels.
- View stock across locations.
- View stock history.
- Activate/deactivate.
- Import/export.

### Acceptance criteria

- Item code must be unique within the school.
- Tracking method must be defined.
- Item details must show stock across authorized locations.
- Items with historical transactions cannot be permanently deleted.

## 10.4 Unit of Measurement

Support common units:

- Pieces.
- Boxes.
- Packets.
- Kilograms.
- Grams.
- Litres.
- Millilitres.
- Metres.
- Sets.
- Pairs.
- Dozens.
- Rolls.
- Other school-defined units.

Conversion between purchase and issue units may be supported through a simple configured conversion.

Example:

1 box = 10 pieces.

Stock quantities must be maintained consistently using the item's defined stock unit.

## 10.5 Campus and Store Management

**Purpose:** Organize physical inventory storage locations.

### Structure

School → Campus → Store → Department/Location.

Individual assets may additionally be assigned to a person.

### Store fields

- Store name.
- Store code.
- Campus.
- Description.
- Location.
- Assigned storekeeper.
- Status.

### Functions

- Create campus-level stores.
- Create multiple stores per campus.
- Assign storekeepers.
- Restrict store access.
- View stock per store.
- Transfer items between stores.
- View consolidated stock.

### Business rules

- Each stock record must belong to a valid location.
- Stock transfers must maintain source and destination references.
- Campus-level users must only access permitted campuses.
- Consolidated reporting must not duplicate stock.

## 10.6 Stock Overview

**Purpose:** Show available and allocated inventory.

### Information

- Item.
- Category.
- Campus.
- Store.
- Total quantity received.
- Available quantity.
- Issued quantity.
- Reserved/allocated quantity, if applicable.
- Damaged quantity.
- Expired quantity.
- Unit.
- Stock value where applicable.

### Actions

- Search.
- Filter.
- Sort.
- View stock details.
- View movement history.
- Start receiving.
- Create issue request.
- Start transfer.
- Export.

### Business rules

- Available quantity must exclude quantities that are damaged, expired or otherwise unavailable.
- Quantity must be tracked independently for each relevant stock location.
- Batch-controlled items must maintain batch-level balances.

## 10.7 Stock Receiving

**Purpose:** Record stock entering a school store.

### Receiving sources

- Purchase order.
- Approved opening stock.
- Authorized stock adjustment.
- Department return.
- Staff/student return.
- Inter-store transfer.
- Other authorized receipt.

### Fields

- Receipt number.
- Receipt date.
- Source.
- Purchase order reference, if applicable.
- Campus.
- Store.
- Vendor/reference.
- Items.
- Received quantity.
- Accepted quantity.
- Rejected quantity.
- Condition.
- Batch number, where applicable.
- Expiry date, where applicable.
- Serial number, where applicable.
- Attachments.
- Remarks.

### Actions

- Create receiving record.
- Add items.
- Record quantities.
- Record inspection result.
- Attach supporting documents.
- Confirm receiving.

### Business rules

- Accepted quantities update stock.
- Rejected quantities do not become available stock.
- Partial receiving must be supported.
- A purchase order may have multiple receiving records.
- Duplicate receiving against the same PO must be prevented through quantity validation.
- All receiving records must be retained.

## 10.8 Stock Issuance

**Purpose:** Distribute items to authorized recipients.

### Request fields

- Request number.
- Request date.
- Requesting person.
- Department.
- Campus.
- Destination.
- Purpose.
- Requested items.
- Requested quantity.
- Remarks.

### Workflow

1. Authorized user creates request.
2. Storekeeper reviews availability.
3. Authorized approver approves or rejects.
4. Storekeeper issues approved quantities.
5. Recipient confirmation is recorded where required.
6. Stock balances are updated.

### Issuance fields

- Issue number.
- Request reference.
- Item.
- Issued quantity.
- Store.
- Recipient.
- Issued by.
- Issue date.
- Remarks.

### Business rules

- Approval is mandatory.
- One approval level is sufficient.
- Approved quantity cannot exceed available stock.
- Partial issuance should be supported.
- Issued quantities must update the stock ledger.
- Rejected requests must not affect stock.
- Issuance history must be maintained.

## 10.9 Stock Returns

**Purpose:** Record unused items returned by recipients or departments.

### Fields

- Return number.
- Original issue reference.
- Returning person.
- Item.
- Returned quantity.
- Condition.
- Return date.
- Destination store.
- Remarks.

### Business rules

- Returned quantity cannot exceed the outstanding issued quantity.
- Returned items must be inspected.
- Usable quantities return to available stock.
- Damaged quantities must be recorded separately.
- Return history must be preserved.

## 10.10 Stock Transfers

**Purpose:** Move stock between stores or campuses.

### Fields

- Transfer number.
- Source campus/store.
- Destination campus/store.
- Requested date.
- Items and quantities.
- Requested by.
- Dispatch date.
- Dispatched by.
- Received date.
- Received by.
- Received quantities.
- Remarks.

### Workflow

Request → Dispatch → Receipt confirmation → Destination stock update.

### Business rules

- Source stock must be available.
- Dispatch reduces source availability.
- In-transit stock must be tracked.
- Destination stock updates upon receipt.
- Partial receipt must be supported.
- Discrepancies must be recorded.
- Complete transfer history must be retained.

## 10.11 Stock Adjustments

**Purpose:** Correct differences between recorded and actual stock.

### Adjustment reasons

- Physical count correction.
- Data entry correction.
- Missing stock.
- Excess stock.
- Damage.
- Expiry.
- Other documented reason.

### Fields

- Adjustment number.
- Store.
- Item.
- Batch/asset reference.
- Existing quantity.
- Adjustment quantity.
- Resulting quantity.
- Reason.
- Evidence/attachment.
- Created by.
- Approval details where applicable.

### Business rules

- Adjustment reasons are mandatory.
- Negative available balances are prohibited.
- Authorized adjustments must be traceable.
- Completed adjustments cannot be silently edited.

## 10.12 Damaged, Expired and Lost Stock

Maintain a separate record for unavailable inventory.

### Required information

- Item.
- Quantity or asset.
- Location.
- Batch reference, if applicable.
- Reason.
- Date identified.
- Reported by.
- Supporting evidence.
- Resolution.

### Supported resolutions

- Return to usable stock after inspection.
- Disposal.
- Write-off.
- Repair.
- Vendor return.
- Other approved resolution.

Expired medicines and food must not be issued as usable stock.

## 10.13 Purchase Request Management

**Purpose:** Allow school departments to request items.

### Fields

- Request number.
- Requesting department.
- Requested by.
- Campus.
- Request date.
- Required date.
- Priority.
- Item.
- Quantity.
- Estimated price.
- Purpose.
- Attachment.
- Remarks.

### Actions

- Create request.
- Edit draft.
- Submit request.
- Approve.
- Reject.
- Return for revision.
- View status.

### Statuses

- Draft.
- Pending approval.
- Approved.
- Rejected.
- Revision requested.
- Partially ordered.
- Ordered.
- Completed.
- Cancelled.

### Business rules

- Approval is mandatory before procurement proceeds.
- Only authorized users can approve.
- Approval and rejection comments should be recorded.
- Approval history must be retained.
- Cancellation must not erase the request.

## 10.14 Vendor Management

### Vendor fields

- Vendor name.
- Vendor code.
- Contact person.
- Phone.
- Email.
- Address.
- Tax registration details, if applicable.
- Website.
- Product categories.
- Documents.
- Notes.
- Status.

### Functions

- Add/edit vendor.
- Activate/deactivate.
- View purchase history.
- View quotations.
- View purchase orders.
- View invoice records.

### Business rules

- Vendor code must be unique.
- Vendor records referenced by purchases cannot be deleted.
- Deactivated vendors cannot be selected for new purchases.

## 10.15 Quotation Management

**Purpose:** Compare quotations before selecting a vendor.

### Quotation fields

- Quotation number.
- Vendor.
- Quotation date.
- Valid until.
- Reference purchase request.
- Item descriptions.
- Quantities.
- Unit prices.
- Discounts.
- Taxes.
- Delivery charges.
- Total amount.
- Delivery timeline.
- Attachment.
- Remarks.

### Functions

- Add multiple quotations.
- Edit draft quotation records.
- Compare vendors.
- Compare unit prices.
- Compare final prices.
- Compare delivery terms.
- Select preferred quotation.
- Record selection reason.

### Business rules

- Multiple quotations must be linked to the same procurement requirement where relevant.
- Selection reason should be recorded.
- Price comparison must use comparable quantities and units.
- Selection must respect the approved purchase request.

## 10.16 Purchase Order Management

### Fields

- PO number.
- Vendor.
- Reference request.
- Selected quotation.
- Campus/delivery location.
- PO date.
- Expected delivery date.
- Items.
- Quantities.
- Unit prices.
- Discounts.
- Taxes.
- Delivery charges.
- Total.
- Terms and conditions.
- Remarks.

### Functions

- Create PO.
- Edit draft PO.
- Generate PDF.
- Share/download PDF.
- Record vendor acknowledgement.
- Track delivery status.
- View receiving history.

### Statuses

- Draft.
- Issued.
- Acknowledged.
- Partially received.
- Fully received.
- Closed.
- Cancelled.

### Business rules

- A PO must reference an approved procurement request.
- Purchase quantities and values must be validated.
- A PO cannot be marked fully received until all accepted quantities are accounted for.
- Changes after issuance must be recorded.
- Cancelled POs must not allow new receiving transactions.

## 10.17 Goods Inspection and Receiving

### Inspection fields

- PO reference.
- Received quantity.
- Accepted quantity.
- Rejected quantity.
- Inspection result.
- Condition.
- Batch details.
- Serial numbers.
- Expiry dates.
- Inspection remarks.
- Photographs/documents.

### Business rules

- Receiving must support multiple deliveries.
- Accepted and rejected quantities must be separately recorded.
- Accepted goods update stock.
- Rejected goods remain outside usable stock.
- Inspection history must be retained.

## 10.18 Vendor Invoice Management

### Fields

- Vendor.
- Invoice number.
- Invoice date.
- PO reference.
- Receiving reference.
- Subtotal.
- Tax.
- Discount.
- Total amount.
- Payment status.
- Paid amount.
- Outstanding amount.
- Attachment.

### Payment statuses

- Unpaid.
- Partially paid.
- Paid.
- Overdue.
- Cancelled.

### Business rules

- Payment status is a record of Finance information, not payment execution.
- Inventory does not process payments.
- Invoice amounts must be traceable to procurement records.
- Invoice attachments must be retained.

## 10.19 Asset Management

**Purpose:** Track individually owned school assets.

### Asset information

- Asset ID.
- Asset name.
- Category.
- Serial number.
- Manufacturer.
- Model.
- Purchase order.
- Vendor.
- Purchase date.
- Purchase price.
- Warranty start/end.
- Current condition.
- Campus.
- Store/location.
- Assigned person.
- Assigned department.
- QR/barcode.
- Image.
- Status.

### Asset statuses

- Available.
- Assigned.
- Under maintenance.
- Under repair.
- Lost.
- Damaged.
- Retired.
- Disposed.

### Functions

- Register asset.
- Generate unique asset ID.
- Generate barcode/QR.
- Assign asset.
- Transfer asset.
- Return asset.
- Update condition.
- Record maintenance.
- Retire/dispose asset.
- View asset history.

### Assignment fields

- Asset.
- Assigned to.
- Assignment type.
- Department.
- Location.
- Assigned date.
- Expected return date, if applicable.
- Assigned by.
- Condition at assignment.
- Acknowledgement.
- Return date.
- Condition at return.

### Business rules

- Asset identifiers must be unique within the school.
- An asset can have only one active custodian at a time.
- Transfers must retain previous assignment history.
- Retired/disposed assets cannot be newly assigned.
- Assignment and return must be recorded.

## 10.20 Maintenance Management

### Maintenance request fields

- Request number.
- Asset.
- Reported by.
- Issue description.
- Priority.
- Reported date.
- Assigned technician/service provider.
- Repair details.
- Repair cost.
- Parts used.
- Attachments.
- Completion date.
- Next service date.

### Statuses

- Open.
- Assigned.
- In progress.
- Waiting for parts.
- Completed.
- Cancelled.

### Business rules

- Maintenance records must be linked to assets where applicable.
- Repair costs must be recorded.
- Asset availability must reflect its maintenance status.
- Completed maintenance records must remain accessible.

## 10.21 Stock Verification

### Workflow

1. Create verification session.
2. Select campus/store.
3. Select categories or items.
4. Generate expected stock list.
5. Scan or enter actual quantities.
6. Identify differences.
7. Add remarks and evidence.
8. Submit discrepancies.
9. Approve required corrections.
10. Apply adjustments.

### Verification fields

- Verification number.
- Store.
- Verification date.
- Item.
- Expected quantity.
- Counted quantity.
- Difference.
- Reason.
- Counted by.
- Reviewed by.
- Status.

### Business rules

- Verification must not directly overwrite historical stock movements.
- Differences must be recorded.
- Adjustments must reference the verification.
- Verification records must remain accessible.

## 10.22 Inventory Notifications

| Event | Notification |
| --- | --- |
| Stock below reorder level | Inventory Manager |
| Out of stock | Inventory Manager |
| Near expiry | Storekeeper |
| Expired stock | Storekeeper |
| Purchase request submitted | Approver |
| Purchase request approved/rejected | Requester |
| Issue request submitted | Approver |
| Issue request approved/rejected | Requester |
| PO delivery overdue | Procurement Officer |
| Warranty approaching expiry | Asset Manager |
| Maintenance due | Responsible user |

Notifications should respect existing ERP notification preferences.

## 10.23 Inventory Reports

| Report | Filters |
| --- | --- |
| Stock Summary | Campus, store, category |
| Item-wise Stock | Item, date, store |
| Stock Movement | Item, movement type, date |
| Stock Valuation | Store, category, date |
| Low Stock | Store, category |
| Expiry Report | Batch, expiry period |
| Purchase History | Vendor, date, campus |
| Vendor Report | Vendor, item |
| Purchase Request Report | Status, department |
| Purchase Order Report | Vendor, status, date |
| Goods Receiving Report | PO, vendor, date |
| Issuance Report | Department, recipient, item |
| Transfer Report | Source, destination |
| Asset Register | Category, campus, status |
| Asset Assignment | Person, department |
| Maintenance Report | Asset, status, date |
| Stock Verification | Store, date, discrepancy |

All reports should support search, filters, date ranges and appropriate CSV/Excel/PDF export.

---

# 11. Library Management – Functional Specification

## 11.1 Library Dashboard

**Purpose:** Show library operations at a glance.

### Dashboard information

- Total book titles.
- Total physical copies.
- Available copies.
- Issued copies.
- Overdue books.
- Reserved books.
- Lost books.
- Damaged books.
- Active student members.
- Active teacher members.
- Pending returns.
- Outstanding fines.

### Filters

- Library.
- Category.
- Member type.
- Date range.

### Actions

- Issue book.
- Return book.
- Add book.
- Add copy.
- Search catalogue.
- View overdue list.
- View pending reservations.
- Open reports.

## 11.2 Library Management

**Purpose:** Allow a school to maintain multiple independent libraries.

### Library fields

- Library name.
- Library code.
- Campus.
- Description.
- Location.
- Librarian/responsible staff.
- Contact details.
- Opening hours.
- Status.

### Functions

- Create library.
- Edit library.
- Activate/deactivate.
- Assign librarians.
- Manage access.
- View collection.
- View transactions.
- View library-specific policies.

### Business rules

- Library code must be unique within the school.
- Every physical book copy must belong to a valid library.
- A library containing historical transactions cannot be permanently deleted.
- Deactivated libraries cannot accept new circulation transactions.

## 11.3 Book Categories and Classification

Default categories (two levels; each has subcategories, e.g. Fiction → Moral Stories, Science → Physics):

- Fiction.
- Science.
- Mathematics.
- Social Studies.
- Languages.
- Reference.
- Biographies.
- General knowledge.
- Custom categories.

Class and language are book fields, not categories; there is no Textbooks category.

### Fields

- Category name.
- Category code.
- Parent category.
- Description.
- Status.

Schools should be able to add and edit categories.

## 11.4 Book Catalogue

**Purpose:** Maintain bibliographic information about each book title/edition.

### Fields

| Field | Required |
| --- | --- |
| Title | Yes |
| ISBN-10/ISBN-13 | No |
| Subtitle | No |
| Author | Yes |
| Publisher | No |
| Edition | No |
| Publication year | No |
| Language | No |
| Category | Yes |
| Description | No |
| Book cover | No |
| Number of pages | No |
| Classification number | No |
| Keywords | No |
| Status | Yes |

Multiple authors should be supported.

### Functions

- Add book.
- Edit book.
- View book.
- Search by title.
- Search by ISBN.
- Search by author.
- Search by publisher.
- Filter by category (a parent includes its subcategories) and by class.
- Import/export.
- View physical copies.

### Business rules

- Duplicate catalogue entries should be identified using ISBN and relevant bibliographic details.
- Books without ISBN must still be supported.
- Catalogue records should be reusable across multiple libraries within the same school.
- Inactive titles cannot be used for new acquisitions without reactivation.

## 11.5 Book Copy / Accession Management

**Purpose:** Track each physical copy independently.

### Copy fields

- Accession number.
- Catalogue reference.
- Library.
- Campus.
- Shelf/location.
- Barcode/QR code.
- Purchase/acquisition date.
- Purchase price.
- Vendor/donor.
- Condition.
- Current status.
- Remarks.

### Copy statuses

- Available.
- Issued.
- Reserved.
- Under maintenance.
- Damaged.
- Lost.
- Withdrawn.

### Functions

- Add individual copy.
- Add multiple copies.
- Generate accession numbers.
- Generate barcode/QR labels.
- Print labels.
- View copy details.
- Change shelf location.
- View issue history.
- View transfer history.

### Business rules

- Accession numbers must be unique within the school.
- Every copy must reference a catalogue record.
- Each copy belongs to one library at a time.
- A copy cannot be issued if it is unavailable.
- Historical accession records must not be deleted.

## 11.6 Book Acquisition

**Purpose:** Record books entering a library collection.

### Acquisition sources

- Purchase.
- Donation.
- Transfer.
- Opening stock import.

### Fields

- Acquisition number.
- Acquisition type.
- Catalogue reference.
- Quantity.
- Destination library.
- Date.
- Vendor/donor.
- Purchase price.
- Invoice/reference.
- Remarks.
- Attachments.

### Business rules

- Each acquired copy must receive a unique accession number.
- Donated books may have zero purchase cost.
- Acquisition history must be retained.
- Library acquisition should operate independently from Inventory procurement.

## 11.7 Membership Management

**Purpose:** Maintain library borrowing eligibility using existing ERP records.

### Supported member types

- Students.
- Teachers.

### Membership information

- Member ID.
- Member type.
- Student/staff reference.
- Eligible libraries.
- Membership start date.
- Membership end date.
- Status.
- Applicable borrowing policy.

### Functions

- View student members.
- View teacher members.
- Activate/deactivate membership.
- Assign library access.
- View borrowing history.
- View outstanding books.
- View outstanding fines.

### Business rules

- Do not create duplicate student or teacher records.
- Existing ERP identity remains the source of truth.
- Inactive members cannot create new borrowing transactions.
- Existing loans must remain visible until resolved.

## 11.8 Borrowing Policy Management

**Purpose:** Configure borrowing rules for each library and member category.

### Policy fields

- Policy name.
- Library.
- Member category.
- Maximum books.
- Borrowing duration.
- Maximum renewals.
- Fine type.
- Fine amount.
- Grace period.
- Maximum fine.
- Book categories the policy applies to (none selected: every category no other policy covers).
- Active status.

### Example

| Member category | Maximum books | Duration | Renewals |
| --- | ---: | ---: | ---: |
| Primary | 1 | 7 days | 1 |
| Middle school | 2 | 14 days | 1 |
| Secondary | 3 | 14 days | 2 |
| Teachers | 5 | 30 days | 2 |

These values are examples only.

### Business rules

- Each library can have different policies.
- Different member categories can have different policies.
- Policy changes must not silently modify existing issue due dates.
- Existing transactions must retain the policy information applied at issue time.
- A member must have an applicable borrowing policy before issuing a book.

## 11.9 Book Issue

**Purpose:** Issue physical copies to students and teachers.

### Issue fields

- Issue number.
- Member.
- Library.
- Book copy.
- Accession number.
- Issue date.
- Due date.
- Issued by.
- Remarks.

### Workflow

1. Identify member.
2. Scan/search book copy.
3. Validate member eligibility.
4. Validate borrowing limits.
5. Validate book availability.
6. Calculate due date.
7. Confirm issue.
8. Update copy status.
9. Generate issue confirmation.

### Validation rules

- Member must be active.
- Member must have borrowing eligibility.
- Maximum book limit must not be exceeded.
- Book copy must be available.
- Applicable restrictions must be checked.
- Existing blocking overdue/lost-book restrictions must be respected.
- A book cannot have multiple active issues.

## 11.10 Book Return

### Return fields

- Return number.
- Issue reference.
- Member.
- Accession number.
- Return date.
- Condition.
- Received by.
- Overdue days.
- Fine amount.
- Remarks.

### Workflow

1. Scan accession number.
2. Identify active issue.
3. Validate return.
4. Inspect physical condition.
5. Calculate overdue fine.
6. Record return.
7. Update copy status.
8. Notify member if applicable.

### Business rules

- A book can only be returned against an active issue.
- Return date must be recorded.
- Returned books must be inspected.
- Damaged books must not automatically become available.
- Fine calculation must follow the policy applicable to the issue.
- Return history must be retained.

## 11.11 Book Renewal

### Renewal fields

- Issue reference.
- Member.
- Existing due date.
- New due date.
- Renewal count.
- Renewed by.
- Renewal date.

### Business rules

- Renewal limit must be enforced.
- Active reservation conflicts must be checked.
- An overdue loan cannot be renewed.
- Renewal history must be retained.
- New due date must follow the applicable policy.

## 11.12 Reservations

**Purpose:** Allow members to reserve books that are currently unavailable.

### Reservation fields

- Reservation number.
- Member.
- Catalogue reference.
- Preferred library.
- Reservation date.
- Queue position.
- Status.
- Expiry date.
- Fulfilled copy.

### Statuses

- Waiting.
- Available for collection.
- Fulfilled.
- Cancelled.
- Expired.

### Workflow

1. Member reserves a title.
2. System checks availability.
3. If unavailable, member enters waiting list.
4. When a copy becomes available, eligible next member is notified.
5. Copy is held for the configured period.
6. Member collects the book or reservation expires.

### Business rules

- Reservation order must be maintained.
- Duplicate active reservations by the same member for the same title should be prevented.
- Only eligible members can reserve.
- Expired reservations should release the held copy.
- Reservation fulfillment must be recorded.

## 11.13 Fine Management

### Supported fine types

1. Per-day overdue fine.
2. Fixed overdue fine.
3. No monetary fine, tracking only.
4. Lost-book replacement charge.
5. Damaged-book penalty.

### Fine fields

- Fine number.
- Member.
- Issue reference.
- Fine type.
- Calculation details.
- Original amount.
- Waived amount.
- Outstanding amount.
- Payment status.
- Date.
- Remarks.

### Fine configuration

- Grace period.
- Fine amount.
- Calculation method.
- Maximum fine.
- Fine exemption.
- Fine waiver.
- Replacement cost.

### Business rules

- Fine calculations must be consistent with the applicable policy.
- Fine records must not be duplicated.
- Waivers require authorization.
- Outstanding balances must remain visible.
- Actual payment processing belongs to Finance.

## 11.14 Lost and Damaged Books

### Lost book information

- Book copy.
- Member.
- Reported date.
- Reason.
- Replacement cost.
- Fine/charge.
- Resolution.
- Remarks.

### Damaged book information

- Book copy.
- Reported by.
- Date.
- Damage severity.
- Description.
- Photographs.
- Penalty.
- Repair status.
- Final condition.

### Business rules

- Lost books must not appear as available.
- Replacement copies must receive new accession numbers.
- Damaged books must be inspected before being made available.
- Historical issue and member responsibility records must remain available.

## 11.15 Inter-library Transfers

### Transfer fields

- Transfer number.
- Source library.
- Destination library.
- Book copies.
- Accession numbers.
- Requested by.
- Transfer date.
- Dispatched by.
- Received by.
- Received date.
- Condition.
- Remarks.

### Workflow

Request → Approval → Dispatch → Receipt confirmation.

### Business rules

- A copy cannot be issued while in transit.
- Source and destination must belong to the same school.
- Destination availability updates after receipt.
- Partial receipt must be supported.
- Transfer history must be retained.

## 11.16 Library Stock Verification

### Workflow

1. Select library.
2. Select shelf/category.
3. Generate expected copy list.
4. Scan physical books.
5. Compare actual and expected copies.
6. Identify missing/unexpected copies.
7. Record discrepancies.
8. Review discrepancies.
9. Approve corrections.
10. Update copy status through appropriate transactions.

### Business rules

- Verification must not silently overwrite accession history.
- Issued books must be identified separately from physically available books.
- Missing copies must be investigated.
- Approved corrections must be traceable.

## 11.17 Library Notifications

| Event | Recipient |
| --- | --- |
| Book issued | Member |
| Book returned | Member |
| Due date approaching | Member |
| Book overdue | Member |
| Reservation available | Member |
| Reservation expiring | Member |
| Fine recorded | Member |
| Membership expiring | Member |
| Lost/damaged book recorded | Member and authorized librarian |

## 11.18 Library Reports

| Report | Filters |
| --- | --- |
| Book Catalogue | Category, author, publisher |
| Accession Register | Library, date, category |
| Library Stock | Library, shelf, category |
| Available Books | Library, category |
| Issued Books | Member, library, date |
| Overdue Books | Member, library, overdue days |
| Member History | Member, date |
| Fine Report | Member, status, date |
| Lost Books | Library, date |
| Damaged Books | Library, condition |
| Acquisition Report | Source, date, library |
| Transfer Report | Source, destination |
| Verification Report | Library, discrepancy |
| Popular Books | Category, period |
| Inactive Books | Library, category |

---

# PART C – SHARED ERP REQUIREMENTS

# 12. User roles and permission matrix

Permissions should be configurable using the existing ERP user/role infrastructure.

Legend:

- F = Full management access.
- A = Approve.
- R = Read/view.
- O = Operational access.
- M = Manage personal records.
- — = No default access.

| Function | Admin | Principal | Inventory Manager | Storekeeper | Procurement | Librarian | Teacher | Student |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Inventory settings | F | R | F | — | — | — | — | — |
| Item management | F | R | F | O | R | — | — | — |
| Stock overview | F | R | F | O | R | — | — | — |
| Stock receiving | F | R | F | O | R | — | — | — |
| Stock issuance | F | A* | O | O | — | — | Request | — |
| Purchase requests | F | A | O | O | O | — | Request | — |
| Procurement | F | A | O | — | O | — | — | — |
| Vendor management | F | R | F | — | O | — | — | — |
| Asset management | F | R | F | O | R | — | R | — |
| Library settings | F | R | — | — | — | F | — | — |
| Book catalogue | F | R | — | — | — | F | R | R |
| Book issue/return | F | R | — | — | — | O | — | — |
| Library reports | F | R | — | — | — | O | — | — |
| Own library records | F | R | — | — | — | R | M | M |

*The principal's approval access and delegated approver responsibilities should be configurable.

Important:

- This is the default role matrix, not a hardcoded permission system.
- A user may hold multiple roles.
- Approval authority must be explicitly assigned.
- Teachers and students must only see records they are authorized to access.
- Backend authorization is mandatory.

# 13. Academic and Financial Year Management

Both modules must retain historical records.

### Academic year

Relevant for:

- Student membership.
- Library borrowing.
- Academic book distribution.
- Department requests.
- Student assignments.
- Academic reports.

### Financial year

Relevant for:

- Purchases.
- Vendor invoices.
- Procurement history.
- Asset purchases.
- Stock valuation reports.

### Requirements

- Support multiple academic years.
- Support multiple financial years.
- Preserve historical records.
- Filter reports by year.
- Do not automatically reset physical stock.
- Carry forward existing stock without duplicating it.
- Preserve previous-year transactions.
- Allow authorized users to view historical data.

### Important distinction

Academic year and financial year are separate concepts.

A transaction should retain its actual transaction date and applicable year references. Changing the active year must not rewrite the transaction.

# 14. Excel/CSV Import and Export

Both modules must provide a standard bulk import feature.

### Import workflow

1. Download template.
2. Fill in records.
3. Upload file.
4. Map columns if needed.
5. Validate records.
6. Preview results.
7. Display errors and warnings.
8. Confirm import.
9. Process valid records.
10. Generate import summary.

### Import summary

- Total rows.
- Successful rows.
- Failed rows.
- Skipped rows.
- Duplicate rows.
- Error descriptions.

### Inventory import templates

- Categories.
- Items.
- Opening stock.
- Store/location records where appropriate.
- Asset register.
- Vendors.

### Library import templates

- Book catalogue.
- Book copies/accession records.
- Member mapping where necessary.

### Business rules

- Invalid rows must not silently import.
- Duplicate item codes and accession numbers must be detected.
- Existing records must not be overwritten without explicit authorization.
- Large imports should be processed safely.
- Import history must be retained.

# 15. Common Search, Filters and Exports

Both modules must support:

- Global module search where useful.
- Search by name and code.
- Advanced filters.
- Sorting.
- Pagination.
- Date ranges.
- Campus/library/store filters.
- CSV export.
- Excel export.
- PDF generation for applicable documents and reports.

# 16. Common Audit History

Maintain an audit history for important operations.

### Information to capture

- User.
- Action.
- Record reference.
- Previous value where applicable.
- New value where applicable.
- Date and time.
- Reason/comment where required.

### Operations requiring audit history

- Item creation and modification.
- Stock adjustments.
- Stock issuance.
- Purchase approval.
- Purchase order changes.
- Asset assignment.
- Asset transfer.
- Book catalogue changes.
- Accession changes.
- Book issue and return.
- Fine waivers.
- Library transfers.
- Permission changes.

Completed transactions must not be silently removed.

# 17. Existing ERP Integration

The modules must reuse existing ERP functionality.

| Existing ERP module | Integration |
| --- | --- |
| School Management | School and campus information |
| Student Management | Student identities |
| Staff Management | Teacher and staff identities |
| User Management | Roles and permissions |
| Authentication | Existing Node.js login |
| Finance | Payment and accounting ownership |
| Notifications | Common notification delivery |
| File Management | Existing attachment capabilities where available |
| Academic Management | Academic year references |
| Reporting | Shared reporting infrastructure where available |

### Integration boundaries

Inventory must not create duplicate student or staff records.

Library must not create duplicate student or teacher records.

Inventory must not become an accounting system.

Library must not become a digital learning-content platform.

Both modules should remain independently operable.

---

# PART D – USER EXPERIENCE REQUIREMENTS

# 18. Flutter Web Requirements

The administrative experience should prioritize operational efficiency.

### Design requirements

- Left-side navigation.
- Clear module dashboards.
- Dense but readable data tables.
- Consistent search and filter controls.
- Quick actions.
- Responsive forms.
- Detail pages with tabs where useful.
- Status indicators.
- Confirmation before sensitive operations.
- Clear success/error feedback.

### Table requirements

Tables should support:

- Search.
- Sorting.
- Filtering.
- Pagination.
- Column selection where useful.
- Bulk selection for safe operations.
- Export.
- Row-level actions.

Avoid excessively spacious layouts and unnecessary navigation.

# 19. Flutter Mobile Requirements

Mobile should prioritize operational tasks.

### Inventory

- Scan item QR/barcodes.
- Receive stock.
- Issue stock after approval.
- Record returns.
- Transfer stock.
- Assign assets.
- Verify physical stock.
- View notifications.

### Library

- Scan accession number.
- Issue books.
- Return books.
- Search catalogue.
- View member information.
- Record damaged books.
- Verify physical copies.

### Offline support

Offline support should initially be limited to safe operations:

- View previously loaded records.
- Capture stock verification.
- Capture barcode scans.
- Synchronize permitted data later.

Book issuance, book returns, stock issuance, purchase approvals and other conflict-sensitive operations should require server confirmation.

---

# PART E – NON-FUNCTIONAL REQUIREMENTS

# 20. Performance

- Search should provide responsive results.
- Lists must use pagination or appropriate incremental loading.
- Large imports must not block the interface.
- Reports should avoid unnecessarily loading all records.
- Images and attachments should be optimized.
- Expensive aggregate calculations should be handled efficiently.

# 21. Security

- Every record must be scoped to the correct school.
- Campus-level restrictions must be enforced.
- Users must not access unauthorized records.
- Sensitive operations must require authorization.
- Backend validation must not rely solely on Flutter.
- File access must respect school and user permissions.
- Audit records must be protected from unauthorized modification.

# 22. Data Integrity

- Unique identifiers must be enforced.
- Stock transactions must be consistent.
- Book copies must not be issued twice.
- Duplicate fines must be prevented.
- Receiving quantities must be validated against purchase orders.
- Transaction history must be preserved.
- Failed operations must not partially update related records.

# 23. Reliability

- Important operations must handle retries safely.
- Duplicate requests must not create duplicate transactions.
- Network interruptions must not silently corrupt data.
- Critical operations must confirm successful server-side completion.
- Background notifications must not generate repeated messages unnecessarily.

# 24. Scalability

The product should support:

- Small schools.
- Large schools.
- Multiple campuses.
- Multiple stores.
- Multiple libraries.
- Large catalogues.
- Large transaction histories.
- Multiple concurrent users.

The implementation should use Firebase capabilities appropriately without introducing unnecessary infrastructure.

# 25. Accessibility and Usability

- Consistent interface patterns.
- Readable text.
- Keyboard navigation on web.
- Clear form validation.
- Meaningful status labels.
- Accessible color contrast.
- Support for barcode scanners and mobile camera scanning.

---

# PART F – TECHNICAL CONSTRAINTS AND BOUNDARIES

# 26. Technology stack

| Technology | Responsibility |
| --- | --- |
| Flutter | Web and mobile UI |
| Node.js | Existing login/authentication |
| Firebase Authentication | Identity integration if required by existing authentication flow |
| Cloud Firestore | Module data |
| Firebase Storage | Images and attachments |
| Cloud Functions | Trusted operations and background jobs |
| Firebase Cloud Messaging | Notifications |
| Firebase Security Rules | Data access enforcement |
| Firebase Analytics | Product usage and events |

### Architecture constraints

1. Do not introduce a new authentication system.
2. Do not duplicate existing ERP master records.
3. Do not introduce separate microservices without a genuine requirement.
4. Do not make Inventory dependent on Library.
5. Do not make Library dependent on Inventory.
6. Use trusted backend operations for sensitive stock and circulation transactions.
7. Maintain strict tenant isolation.
8. Keep business logic maintainable and testable.

### Authentication clarification

The existing Node.js login flow must be reviewed to determine how users obtain Firebase-compatible credentials.

Do not assume that a Node.js application session automatically grants secure Firestore access.

# 27. Data ownership boundaries

| Data | Owner |
| --- | --- |
| School identity | Existing ERP |
| Campus identity | Existing ERP |
| Student records | Student Management |
| Staff/teacher records | Staff Management |
| Authentication | Existing Node.js system |
| Inventory items | Inventory |
| Inventory stock movements | Inventory |
| Vendors | Inventory |
| Procurement | Inventory |
| Assets | Inventory |
| Library catalogue | Library |
| Book copies | Library |
| Library memberships | Library, linked to ERP identities |
| Book circulation | Library |
| Library fines | Library |
| Actual payments | Finance |

---

# PART G – IMPLEMENTATION ROADMAP

# 28. Inventory Development Phases

| Phase | Features | Completion outcome |
| --- | --- | --- |
| 1 | Categories, units, items, tracking methods, stores | Inventory master data ready |
| 2 | Stock receiving, issuance, returns, transfers | Core stock operations ready |
| 3 | Purchase requests, approvals, vendors | Procurement initiation ready |
| 4 | Quotations, comparisons, purchase orders | Purchasing ready |
| 5 | Goods receiving, inspection, invoices | Procurement lifecycle complete |
| 6 | Asset registration, assignment, maintenance | Asset management ready |
| 7 | Stock verification, reports, notifications | Operational management complete |
| 8 | Scanning, RFID integration and offline improvements | Hardware and field operations improved |

# 29. Library Development Phases

| Phase | Features | Completion outcome |
| --- | --- | --- |
| 1 | Libraries, categories, catalogue | Library master data ready |
| 2 | Copies, accession numbers, barcodes | Physical collections ready |
| 3 | Memberships and borrowing policies | Membership ready |
| 4 | Issue, return and renewal | Circulation ready |
| 5 | Reservations and waiting lists | Reservation management ready |
| 6 | Fines, lost and damaged books | Exception handling ready |
| 7 | Transfers and stock verification | Multi-library operations ready |
| 8 | Reports, notifications and app integration | Complete library solution |

# 30. Testing and Acceptance Strategy

## Inventory test scenarios

- Create multiple campuses.
- Create multiple stores.
- Add different tracking methods.
- Receive stock.
- Receive partial purchase deliveries.
- Reject damaged goods.
- Track batch expiry.
- Issue stock with approval.
- Reject issuance.
- Attempt issuance beyond available stock.
- Return unused stock.
- Transfer between campuses.
- Handle partial transfer receipt.
- Assign assets to teachers and students.
- Record asset repairs.
- Complete stock verification.
- Import opening stock.
- View previous financial-year records.

## Library test scenarios

- Create multiple libraries.
- Create catalogue records.
- Add multiple copies.
- Generate accession numbers.
- Issue books to students.
- Issue books to teachers.
- Enforce borrowing limits.
- Attempt duplicate book issue.
- Return books.
- Renew books.
- Handle overdue books.
- Calculate different fine types.
- Waive fines.
- Reserve unavailable books.
- Process reservation queues.
- Handle expired reservations.
- Record lost and damaged books.
- Transfer books between libraries.
- Verify physical stock.
- Import existing catalogue and copies.
- View previous academic-year history.

## Security test scenarios

- User from School A attempts to access School B data.
- Campus user attempts to access another campus.
- Student attempts to view another student's library records.
- Teacher attempts to modify administrative inventory data.
- Unauthorized user attempts approval.
- User attempts to modify completed transactions.
- Unauthorized user attempts to access attachments.

All critical security and data-integrity tests must pass before production release.

---

# PART H – ACCEPTANCE CRITERIA

# 31. Inventory Module – Definition of Done

Inventory is ready for production when:

- [ ] Categories and items can be managed.
- [ ] Quantity, batch and asset tracking work correctly.
- [ ] Multiple campuses and stores work correctly.
- [ ] Stock receiving works.
- [ ] Stock issuance requires approval.
- [ ] Stock returns work.
- [ ] Stock transfers work.
- [ ] Stock adjustments are auditable.
- [ ] Procurement lifecycle is complete.
- [ ] Multiple vendor quotations can be compared.
- [ ] Purchase orders can be generated as PDFs.
- [ ] Partial receiving works.
- [ ] Invoice records are maintained.
- [ ] Assets can be assigned and transferred.
- [ ] Maintenance records work.
- [ ] Physical verification works.
- [ ] Reports and exports work.
- [ ] Excel/CSV imports work.
- [ ] Historical records are retained.
- [ ] Permissions and tenant isolation are verified.

# 32. Library Module – Definition of Done

Library is ready for production when:

- [ ] Multiple libraries can be managed.
- [ ] Book catalogue works.
- [ ] Physical copies can be registered.
- [ ] Unique accession numbers are enforced.
- [ ] Barcode/QR functionality works.
- [ ] Student and teacher membership works.
- [ ] Library-specific borrowing policies work.
- [ ] Book issue works.
- [ ] Book return works.
- [ ] Renewal restrictions work.
- [ ] Reservations and waiting lists work.
- [ ] All approved fine types work.
- [ ] Lost and damaged book handling works.
- [ ] Inter-library transfers work.
- [ ] Physical verification works.
- [ ] Students can view their own records.
- [ ] Teachers can view their own records.
- [ ] Reports and notifications work.
- [ ] Excel/CSV imports work.
- [ ] Historical records are retained.
- [ ] Permissions and tenant isolation are verified.

---

# PART I – IMPLEMENTATION GUARDRAILS

# 33. What we should avoid

To prevent unnecessary complexity:

1. Do not build a generic enterprise workflow engine.
2. Do not build an accounting system inside Inventory.
3. Do not duplicate ERP student/staff management.
4. Do not build digital library functionality in the first release.
5. Do not create separate applications for individual roles.
6. Do not introduce microservices unnecessarily.
7. Do not make RFID mandatory.
8. Do not overcomplicate approval workflows.
9. Do not create unnecessary configurable fields.
10. Do not build analytics infrastructure before operational data is available.

# 34. Important functional distinctions

The following distinctions must be maintained during implementation:

**Inventory item vs asset**

An inventory item represents a type of product. An asset represents an individually identifiable physical object.

**Book catalogue vs book copy**

A catalogue record describes a title/edition. A copy represents an individual physical book with its own accession number.

**Stock quantity vs stock movement**

A stock balance represents the current quantity. A stock movement represents the transaction that changed it.

**Library fine vs payment**

Library calculates and maintains the fine. Finance owns actual payment processing.

**Purchase invoice vs payment**

Inventory maintains vendor invoice records. Finance owns payments and accounting.

**Academic year vs financial year**

They are separate periods and must not be treated as interchangeable.

---

# PART J – FINAL PRODUCT APPROVAL

# 35. Requirements baseline summary

| Area | Final decision |
| --- | --- |
| Target schools | K–12 |
| Inventory independence | Yes |
| Library independence | Yes |
| Multiple campuses | Yes |
| Multiple stores | Yes |
| Multiple libraries | Yes |
| Quantity tracking | Yes |
| Batch tracking | Yes |
| Individual asset tracking | Yes |
| Complete procurement | Yes |
| Single-level approvals | Yes |
| Staff/student asset assignment | Yes |
| Physical library | Yes |
| Student/teacher borrowing | Yes |
| Library-specific policies | Yes |
| Reservations | Yes |
| Fines and penalties | Yes |
| Inter-library transfers | Yes |
| Barcode/QR | Yes |
| RFID integration | Supported as an integration capability |
| Offline functionality | Limited and safe operations |
| Excel/CSV import | Both modules |
| Historical records | Retained |
| Global localization | Deferred |
| Technology | Flutter + Firebase |
| Login | Existing Node.js |

# 36. Next deliverables – before coding

This PRD and FRS establish the product and functional requirements. They are not yet a complete technical implementation specification.

The next documents should be prepared in this order:

| Order | Document | Purpose |
| --- | --- | --- |
| 1 | Screen-by-Screen UI Specification | Exact screens, fields, buttons, tables and interactions |
| 2 | Permission Matrix | Exact actions permitted for each role |
| 3 | Business Rules & Validation Catalogue | Detailed validations and exceptional cases |
| 4 | Firebase Technical Architecture | Data ownership, collections, security and backend operations |
| 5 | Integration Specification | Existing ERP integration contracts |
| 6 | Test Specification | Functional, integration, security and acceptance tests |
| 7 | Development Plan | Tasks, dependencies and implementation sequence |

**Development must not begin until the functional requirements, UI specification and technical architecture are reviewed and approved.**

---

## Final product direction

The Inventory module should become the school's central system for managing everything it purchases, stores, distributes and owns.

The Library module should become the school's central system for managing physical books, collections, members and borrowing operations.

Both should be comprehensive enough for different types and sizes of K–12 schools, while remaining straightforward to configure, operate and maintain.

**The guiding principle is simple: comprehensive functionality, straightforward workflows and maintainable implementation.**
