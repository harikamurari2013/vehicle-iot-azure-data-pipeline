/**
 * Azure Function: BlobTriggerValidator
 *
 * Trigger  : Fires on new blob in ADLS Gen2 input/landing/ container
 * On Valid  : Routes file → staging/   (Pipeline 2 picks it up for SQL load)
 * On Invalid: Routes file → rejected/  (dead-letter for review)
 */

module.exports = async function (context, myBlob) {
    context.log("********Azure Function Started********");
    context.log("Processing blob:", context.bindingData.name);

    let isValid = true;

    try {
        const rawContent = myBlob.toString().trim().replace(/\n/g, ' ');

        // Step 1: Must be parseable JSON
        const parsed = JSON.parse(rawContent);

        // Step 2: Handle both single object {} and array of objects [{}]
        const records = Array.isArray(parsed) ? parsed : [parsed];

        if (records.length === 0) {
            context.log.warn("Validation failed — JSON array is empty.");
            isValid = false;
        } else {
            // Step 3: Validate required fields match Customer.json schema
            const requiredFields = ["VehicleID", "latitiude", "longitude", "City", "temeprature", "speed"];

            for (let i = 0; i < records.length; i++) {
                const missingFields = requiredFields.filter(field => !(field in records[i]));
                if (missingFields.length > 0) {
                    context.log.warn(`Record[${i}] failed — missing fields: ${missingFields.join(", ")}`);
                    isValid = false;
                    break;
                }
            }

            if (isValid) {
                context.log(`Validation passed — ${records.length} vehicle record(s) found.`);
                context.log(`Sample VehicleID: ${records[0].VehicleID}, City: ${records[0].City}`);
            }
        }

    } catch (exception) {
        context.log.error(`JSON parse error: ${exception.message}`);
        isValid = false;
    }

    if (isValid) {
        context.bindings.stagingFolder = myBlob.toString();
        context.log("********File Copied to Staging Folder Successfully********");
    } else {
        context.bindings.rejectedFolder = myBlob.toString();
        context.log("********Invalid JSON File Copied to Rejected Folder Successfully********");
    }

    context.log("*******Azure Function Ended Successfully*******");
};
