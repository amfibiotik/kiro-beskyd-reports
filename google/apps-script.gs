/**
 * Google Apps Script — Web App for creating spreadsheets from a template.
 * 
 * Deploy:
 * 1. Open https://script.google.com → New project
 * 2. Paste this code replacing Code.gs
 * 3. Deploy → New deployment → Web app
 *    - Execute as: Me (your account)
 *    - Who has access: Anyone
 * 4. Copy deployment URL → paste into ~/.kiro/skills/weekly-report/folders.yaml as apps_script_url
 *
 * API:
 *   POST {url}
 *   Body: {"action": "create_spreadsheet", "title": "Report...", "folder_id": "..."}
 *   Response: {"spreadsheet_id": "...", "url": "..."}
 *
 *   POST {url}
 *   Body: {"action": "create_folder", "name": "07-July", "parent_id": "..."}
 *   Response: {"folder_id": "...", "name": "..."}
 */

// REPLACE with your own template spreadsheet ID (see GOOGLE_SETUP.md Step 4)
var TEMPLATE_ID = "__YOUR_TEMPLATE_SPREADSHEET_ID__";

function doPost(e) {
  try {
    var payload = JSON.parse(e.postData.contents);
    var action = payload.action;

    if (action === "create_spreadsheet") {
      return createSpreadsheet(payload.title, payload.folder_id);
    } else if (action === "create_folder") {
      return createFolder(payload.name, payload.parent_id);
    } else {
      return jsonResponse({error: "Unknown action: " + action});
    }
  } catch (err) {
    return jsonResponse({error: err.message});
  }
}

function doGet(e) {
  return jsonResponse({status: "ok", message: "Weekly Report Apps Script is running"});
}

function createSpreadsheet(title, folderId) {
  var template = DriveApp.getFileById(TEMPLATE_ID);
  var folder = DriveApp.getFolderById(folderId);
  var copy = template.makeCopy(title, folder);

  return jsonResponse({
    spreadsheet_id: copy.getId(),
    url: "https://docs.google.com/spreadsheets/d/" + copy.getId() + "/edit"
  });
}

function createFolder(name, parentId) {
  var parent = DriveApp.getFolderById(parentId);
  var folder = parent.createFolder(name);

  return jsonResponse({
    folder_id: folder.getId(),
    name: folder.getName()
  });
}

function jsonResponse(data) {
  return ContentService
    .createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}
