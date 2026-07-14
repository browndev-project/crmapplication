// ignore_for_file: constant_identifier_names

class PermissionModules {
  // Roles
  static const String SALES_MANAGER = 'sales_manager';
  static const String SALES_EXECUTIVE = 'sales_executive';
  static const String TEAM_LEADER = 'team_leader';
  static const String COMPANY_ADMIN = 'company_admin';

  // Modules
  static const String BASE = "modules.base";
  static const String LEADS = "modules.lead";
  static const String SERVICES = "modules.service";
  static const String PRODUCTS = "modules.product";
  static const String PROPERTY = "modules.property";
  static const String TRIP = "modules.trip";
  static const String VISITS = "modules.visit";
  static const String MEETING = "modules.meeting";
  static const String TASK = "modules.task";
  static const String ASSETS = "modules.asset";
  static const String ATTENDANCE = "modules.attendance";
  static const String INVOICE = "modules.invoice";
  static const String QUOTATION = "modules.quotation";
  static const String VOUCHER = "modules.voucher";
  static const String ITINERARY = "modules.itinerary";
  static const String WHATSAPP = "modules.whatsapp";
  static const String MARKETING = "modules.marketing";
  static const String TOOLS = "modules.tool";
  static const String CALENDAR = "modules.calendar";
  static const String LEAD_DOCS = "modules.leadDocs";
  static const String INTEGRATION = "modules.integration";
  static const String INTEGRATION_META = "modules.integration.meta";
  static const String INTEGRATION_WHATSAPP = "modules.integration.whatsapp";
  static const String INTEGRATION_WEBSITE = "modules.integration.website";
  static const String INTEGRATION_JUSTDIAL = "modules.integration.justdial";
  static const String INTEGRATION_INDIAMART = "modules.integration.indiamart";
  static const String INTEGRATION_SULEKHA = "modules.integration.sulekha";
  static const String INTEGRATION_99ACRES = "modules.integration.99acres";
  static const String INTEGRATION_HOUSING = "modules.integration.housing";
  static const String INTEGRATION_MAGICBRICKS = "modules.integration.magicbricks";
  static const String INTEGRATION_IVR = "modules.integration.ivr";

  static const String STAFF_BASE = "modules.staff.base";
  static const String STAFF_GROUP = "modules.staff.group";
  static const String STAFF_TEAM = "modules.staff.team";

  static const String REPORTS_BASE = "modules.report.base";
  static const String REPORTS_TODAY = "modules.report.today";
  static const String REPORTS_OVERALL = "modules.report.overall";
  static const String REPORTS_PERFORMANCE = "modules.report.performance";
  static const String REPORTS_SERVICES = "modules.report.service";
  static const String REPORTS_PRODUCTS = "modules.report.product";
  static const String REPORTS_PROPERTY = "modules.report.property";

  // Permissions - Leads
  static const String LEADS_VIEW = "leads.view";
  static const String LEADS_DELETE = "leads.delete";
  static const String LEADS_DOWNLOAD = "leads.download";
  static const String LEADS_CREATE_MANUAL = "leads.createManual";
  static const String LEADS_BULK_UPLOAD = "leads.bulkUpload";
  static const String LEADS_ASSIGN = "leads.assign";
  static const String LEADS_CALL_PLAY = "leads.call.play";
  static const String LEADS_CALL_DOWNLOAD = "leads.call.download";
  static const String LEADS_CALL = "leads.call";
  static const String LEADS_WHATSAPP = "leads.whatsapp";
  static const String LEADS_MAIL = "leads.mail";
  static const String LEADS_BULK_ASSIGN = "leads.bulkAssign";
  static const String LEADS_UPDATE_DETAILS = "leads.updateDetails";
  static const String LEADS_UPDATE_STATUS = "leads.updateStatus";
  static const String LEADS_UPDATE_PIPELINE = "leads.updatePipeline";
  static const String LEADS_BULK_UPDATE = "leads.bulkUpdate";

  // Lead Documents
  static const String LEAD_DOCS_VIEW = "leads.docs.view";
  static const String LEAD_DOCS_UPLOAD = "leads.docs.upload";
  static const String LEAD_DOCS_DELETE = "leads.docs.delete";
  static const String LEAD_DOCS_DOWNLOAD = "leads.docs.download";
  static const String LEAD_DOCS_REQUEST = "leads.docs.request";
  static const String LEAD_DOCS_FORM_CREATE = "leads.docs.form.create";
  static const String LEAD_DOCS_FORM_EDIT = "leads.docs.form.edit";
  static const String LEAD_DOCS_FORM_DELETE = "leads.docs.form.delete";
  static const String LEAD_DOCS_LOCK = "leads.docs.lock";

  // Marketing
  static const String MARKETING_MAIL = "marketing.mail";
  static const String MARKETING_TEMPLATES_VIEW = "marketing.templates.view";
  static const String MARKETING_TEMPLATES_CREATE = "marketing.templates.create";

  // Tasks
  static const String TASKS_VIEW = "tasks.view";
  static const String TASKS_CREATE = "tasks.create";
  static const String TASKS_UPDATE = "tasks.update";
  static const String TASKS_DELETE = "tasks.delete";

  // Invoice
  static const String INVOICE_VIEW = "invoice.view";
  static const String INVOICE_DOWNLOAD = "invoice.download";
  static const String INVOICE_SEND = "invoice.send";
  static const String INVOICE_CREATE = "invoice.create";
  static const String INVOICE_UPDATE = "invoice.update";
  static const String INVOICE_DELETE = "invoice.delete";
  static const String INVOICE_UPDATE_STATUS = "invoice.updateStatus";
  static const String INVOICE_SHARE = "invoice.share";

  // Itinerary
  static const String ITINERARY_VIEW = "itinerary.view";
  static const String ITINERARY_DOWNLOAD = "itinerary.download";
  static const String ITINERARY_SEND = "itinerary.send";
  static const String ITINERARY_CREATE = "itinerary.create";
  static const String ITINERARY_DELETE = "itinerary.delete";
  static const String ITINERARY_UPDATE = "itinerary.update";
  static const String ITINERARY_PREVIEW = "itinerary.preview";
  static const String ITINERARY_DUPLICATE = "itinerary.duplicate";
  static const String ITINERARY_GENERATE_QUOTE = "itinerary.generate_quote";

  // Templates
  static const String TEMPLATE_VIEW = "template.view";
  static const String TEMPLATE_CREATE = "template.create";
  static const String TEMPLATE_EDIT = "template.edit";
  static const String TEMPLATE_DELETE = "template.delete";
  static const String TEMPLATE_PREVIEW = "template.preview";
  static const String TEMPLATE_SELECT = "template.select";

  // Voucher
  static const String VOUCHER_VIEW = "voucher.view";
  static const String VOUCHER_DOWNLOAD = "voucher.download";
  static const String VOUCHER_SEND = 'voucher.send';
  static const String VOUCHER_SHARE = 'voucher.share';
  static const String VOUCHER_CREATE = 'voucher.create';

  // Quotation permissions
  static const String QUOTATION_VIEW = 'quotation.view';
  static const String QUOTATION_CREATE = 'quotation.create';
  static const String QUOTATION_UPDATE = 'quotation.update';
  static const String QUOTATION_DELETE = 'quotation.delete';
  static const String QUOTATION_DOWNLOAD = 'quotation.download';
  static const String QUOTATION_SEND = 'quotation.send';
  static const String QUOTATION_SHARE = 'quotation.share';

  static const String VOUCHER_UPDATE = "voucher.update";
  static const String VOUCHER_DELETE = "voucher.delete";

  // Meetings
  static const String MEETINGS_VIEW = "meetings.view";
  static const String MEETINGS_CREATE = "meetings.create";
  static const String MEETINGS_UPDATE = "meetings.update";
  static const String MEETINGS_DELETE = "meetings.delete";

  // Visits
  static const String VISITS_VIEW = "visits.view";
  static const String VISITS_CREATE = "visits.create";
  static const String VISITS_UPDATE = "visits.update";
  static const String VISITS_UPDATE_STATUS = "visits.updateStatus";
  static const String VISITS_DELETE = "visits.delete";

  // Project
  static const String PROJECT_VIEW = "project.view";
  static const String PROJECT_CREATE = "project.create";
  static const String PROJECT_UPDATE = "project.update";
  static const String PROJECT_UPDATE_STATUS = "project.updateStatus";
  static const String PROJECT_DELETE = "project.delete";
  static const String PROJECT_BULK_UPDATE = "project.bulkUpdate";

  // Property
  static const String PROPERTY_VIEW = "property.view";
  static const String PROPERTY_CREATE = "property.create";
  static const String PROPERTY_UPDATE = "property.update";
  static const String PROPERTY_UPDATE_STATUS = "property.updateStatus";
  static const String PROPERTY_DELETE = "property.delete";
  static const String PROPERTY_BULK_UPDATE = "property.bulkUpdate";
  static const String PROPERTY_LAST_UPDATED = "property.lastUpdate";

  // Trip
  static const String TRIP_VIEW = "trip.view";

  // Services
  static const String SERVICES_VIEW = "services.view";
  static const String SERVICES_CREATE = "services.create";
  static const String SERVICES_UPDATE = "services.update";
  static const String SERVICES_DELETE = "services.delete";

  // Products
  static const String PRODUCTS_VIEW = "products.view";
  static const String PRODUCTS_CREATE = "products.create";
  static const String PRODUCTS_UPDATE = "products.update";
  static const String PRODUCTS_DELETE = "products.delete";

  // Assets
  static const String ASSETS_VIEW = "assets.view";
  static const String ASSETS_CREATE = "assets.create";
  static const String ASSETS_DELETE = "assets.delete";
  static const String ASSETS_DOWNLOAD = "assets.download";

  // Calendar
  static const String CALENDAR_VIEW = "calendar.view";

  // Integrations
  static const String INTEGRATION_IVR_CALL = "integrations.ivr.call";

  // Sales Executives
  static const String SALES_EXEC_VIEW = "salesExecutives.view";
  static const String SALES_EXEC_CREATE = "salesExecutives.create";
  static const String SALES_EXEC_UPDATE = "salesExecutives.update";
  static const String SALES_EXEC_DELETE = "salesExecutives.delete";

  // Sales Managers
  static const String SALES_MANAGER_VIEW = "salesManagers.view";
  static const String SALES_MANAGER_CREATE = "salesManagers.create";
  static const String SALES_MANAGER_UPDATE = "salesManagers.update";
  static const String SALES_MANAGER_DELETE = "salesManagers.delete";

  // Team Leaders
  static const String TEAM_LEADER_VIEW = "teamLeaders.view";
  static const String TEAM_LEADER_CREATE = "teamLeaders.create";
  static const String TEAM_LEADER_UPDATE = "teamLeaders.update";
  static const String TEAM_LEADER_DELETE = "teamLeaders.delete";

  // Groups
  static const String STAFF_GROUP_VIEW = "staff.group.view";
  static const String STAFF_GROUP_CREATE = "staff.group.create";
  static const String STAFF_GROUP_UPDATE = "staff.group.update";
  static const String STAFF_GROUP_DELETE = "staff.group.delete";

  // Teams
  static const String STAFF_TEAM_VIEW = "staff.team.view";
  static const String STAFF_TEAM_CREATE = "staff.team.create";
  static const String STAFF_TEAM_UPDATE = "staff.team.update";
  static const String STAFF_TEAM_DELETE = "staff.team.delete";
}

