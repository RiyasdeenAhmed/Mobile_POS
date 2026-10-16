# Retail tools and visual refresh

## Interface

The app uses the supplied blue (#0066FF), off-white, black and gray palette,
with locally bundled Inter and Space Grotesk fonts. Shared themes apply rounded
cards, fields, dialogs and actions across existing screens. New Sale uses an
adaptive product grid with icon tiles, stock status and add controls. Checkout
keeps its submit button above the keyboard. Light/dark/system preferences remain.

## Invoice files

Settings → Invoice destination selects or resets a default folder. Sale detail
offers Save Invoice, Save As and Share Invoice. Save As does not change the default.
Android uses Storage Access Framework tree/document URIs with persistable grants;
desktop uses native file pickers. A default-folder name collision gets a numbered
suffix; Save As uses the system's overwrite confirmation. Cancelling is harmless.
If access is revoked, use Save As or choose the folder again. Sharing creates a
temporary app-owned file. None of these operations changes the completed sale.

## Profit and expenses

Administrators see daily and monthly profit on Dashboard and can open More →
Profit for historical days/months. Gross profit is completed sale-item revenue
after discounts, excluding sales tax, minus historical sale-item cost. Credit
sales count at completion; debt repayments do not count again. Returns deduct
recorded refunds and reverse historical cost on the return date. The existing
return service does not separately record refunded tax, so no tax split is inferred.
Fractional return cost reversals use cumulative rounding to preserve total cost.
Zero-cost sale lines show a warning. Reports use local calendar boundaries and UTC
storage, refreshing after financial writes, app resume and once per minute.

More → Expenses allows administrators to record amount, category, date and note.
Net profit subtracts active dated expenses. Correct creates a replacement and voids
the original atomically. Void requires a reason. Original values, staff attribution,
timestamps and replacement links remain stored. There are no recurring expenses.

## CSV product import

Products → Import CSV provides a template and preview. Files must be UTF-8 and at
most 5 MB. Headers are:

```csv
name,sku,barcode,category,cost_price,selling_price,opening_stock,reorder_level,track_stock
```

Name and selling_price are required. Prices use the store currency, a decimal point
and at most two decimal places. Optional numeric fields default to zero; track_stock
defaults to true. Quoted fields, embedded commas, escaped quotes, LF/CRLF and a UTF-8
BOM are supported. Barcode/SKU leading zeros are retained by the importer; spreadsheet
editors must also preserve these columns as text before export.

Existing SKU/barcode matches are skipped. Conflicting matches, repeated identifiers
and invalid values show row errors. Correct the source and reload, or uncheck bad
rows. Selected valid products, categories and opening-stock movements commit together.
The service rechecks existing identifiers at commit time. It does not update existing
prices, quantities or product details.

## Barcode labels

More → Barcode Labels, Products toolbar and product actions open the label screen.
Existing codes are retained. Create Barcode asks for confirmation before saving a
unique internal Code 128 value. Label dimensions default to 50 × 30 mm, with optional
price and 1–100 copies. PDF contains the selected number of pages; PNG contains one
203-dpi label, with copy count selected in the printer app. Supported dimensions are
30–150 mm wide and 20–150 mm high.

Open barcode app launches Android package `com.xinye.barcode4`, falling back to its
Play Store page if absent. Import the exported file or enter the barcode manually;
there is no verified automatic editor-transfer interface. This does not claim direct
printer integration. Inspect and scan a printed label before operational use.

## Implementation and validation

Schema v6 adds the indexed expenses table and audit fields without changing previous
migrations. Financial services emit a database-owned revision notification after a
successful commit so profit panels can refresh. SQL stays in repositories/services.
Platform file operations are behind RetailFiles and invoice destination policy is
behind InvoiceDestination. New unit/database tests are in retail_tools_test.dart;
retail_visual_test.dart renders light/dark phone/tablet screenshots under build/ui-preview.

The initial baseline had clean analysis and 234 passing tests with one existing
Windows invoice-path test failure. Invoice path normalization fixes that failure.
An Android debug build has succeeded. Physical document-provider permission lifecycle,
camera scan-back, external barcode-app import, and actual printing still require a
phone/printer. The Windows host requires Visual Studio C++ tooling to launch the
desktop build; it is not installed on this machine.

Suggested commit: `feat: refresh POS UI and add profit, CSV, invoice export and barcode tools`

Final regression run: **248 tests passed**, including the new retail service and
phone/tablet light/dark rendering tests. Static analysis reported no issues.
An Android emulator was created and the debug app launched successfully; the
connected Pixel 7 Pro is the physical-device run target. Printer and external
barcode-app interoperability remain manual checks.
