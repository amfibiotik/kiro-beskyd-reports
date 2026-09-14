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
 *
 *   POST {url}
 *   Body: {"action": "trim_rows", "spreadsheet_id": "...", "data_rows": 4}
 *   Response: {"spreadsheet_id": "...", "rows_deleted": 1, "total_rows": 6}
 *   Note: Removes empty rows between data and Total row.
 *         Template has 5 data rows (2-6) + Total (7). If data_rows < 5,
 *         deletes the extra empty rows so Total sits right after last data row.
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
    } else if (action === "trim_rows") {
      return trimRows(payload.spreadsheet_id, payload.data_rows);
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

/**
 * Remove extra empty rows between data and Total row.
 *
 * Template structure: Header (row 1) + 5 data rows (2-6) + Total (row 7)
 * If actual data_rows < 5, we need to delete the unused rows so that:
 *   - Total moves up to row (data_rows + 2)
 *   - Data validation on deleted rows disappears
 *
 * @param {string} spreadsheetId - The spreadsheet ID
 * @param {number} dataRows - Number of actual data rows written (e.g., 4)
 */
function trimRows(spreadsheetId, dataRows) {
  var ss = SpreadsheetApp.openById(spreadsheetId);
  var sheet = ss.getSheets()[0]; // Sheet1

  var templateDataRows = 5; // template always has 5 data row slots
  var rowsToDelete = templateDataRows - dataRows;

  if (rowsToDelete <= 0) {
    return jsonResponse({
      spreadsheet_id: spreadsheetId,
      rows_deleted: 0,
      total_rows: sheet.getLastRow()
    });
  }

  // Delete rows starting from (header + dataRows + 1) = first empty row after data
  // Row index is 1-based: header=1, data=2...(dataRows+1), first empty=(dataRows+2)
  var firstRowToDelete = dataRows + 2;
  sheet.deleteRows(firstRowToDelete, rowsToDelete);

  return jsonResponse({
    spreadsheet_id: spreadsheetId,
    rows_deleted: rowsToDelete,
    total_rows: sheet.getLastRow()
  });
}

function jsonResponse(data) {
  return ContentService
    .createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}
