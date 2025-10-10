// ================================
// Scripted Jenkins Pipeline for Salesforce Metadata Backup & Deploy
// ================================

node {

    // -------------------------------
    // Build Parameters (with Red * for mandatory fields)
    // -------------------------------
    properties([
        parameters([
            string(name: 'OrgAlias', description: '<font color="red">*</font> Salesforce Org Alias (Mandatory)'),
            string(name: 'OrgUrl', description: '<font color="red">*</font> Salesforce Org URL (Mandatory)'),
            string(name: 'XML_PATH', description: '<font color="red">*</font> Path to XML file relative to repo root (e.g., force-app/main/default/settings/Security.settings-meta.xml)'),
            
            text(name: 'TagNames', description: '<font color="red">*</font> Comma-separated Tag Names (e.g., Name,Description,IsActive)'),
            text(name: 'TagValues', description: '<font color="red">*</font> Comma-separated Tag Values (e.g., Dev,Test,True)'),
            
            string(name: 'BackupFolder', defaultValue: 'backups', description: 'Backup folder name (default: backups)')
        ])
    ])

    // -------------------------------
    // Validate Parameters
    // -------------------------------
    stage('Validate Parameters') {
        echo "Validating mandatory parameters..."

        def missingParams = []
        if (!params.OrgAlias?.trim()) missingParams << 'OrgAlias'
        if (!params.OrgUrl?.trim()) missingParams << 'OrgUrl'
        if (!params.XML_PATH?.trim()) missingParams << 'XML_PATH'
        if (!params.TagNames?.trim()) missingParams << 'TagNames'
        if (!params.TagValues?.trim()) missingParams << 'TagValues'

        if (missingParams) {
            error("Missing mandatory parameters: ${missingParams.join(', ')}")
        }

        // Assign trimmed values
        ORG_ALIAS   = params.OrgAlias.trim()
        ORG_URL     = params.OrgUrl.trim()
        XML_PATH    = params.XML_PATH.trim()
        TAG_NAMES   = params.TagNames.trim()
        TAG_VALUES  = params.TagValues.trim()
        BACKUP_DIR  = params.BackupFolder?.trim() ?: 'backups'

        // Normalize XML path to absolute path within workspace
        if (!XML_PATH.startsWith('/') && !XML_PATH.matches('^[A-Za-z]:.*')) {
            XML_PATH = "${env.WORKSPACE}/${XML_PATH}"
        }
        if (!isUnix()) {
            XML_PATH = XML_PATH.replace('/', '\\')
        }

        echo "Parameters validated successfully"
        echo "Resolved XML_PATH: ${XML_PATH}"
    }

    // -------------------------------
    // Create Backup Folder and Copy File
    // -------------------------------
    stage('Backup XML to /backups folder') {
        try {
            def timestamp = new Date().format('yyyyMMdd_HHmmss')
            def backupPath = "${BACKUP_DIR}/backup_${timestamp}"

            echo "Creating backup folder under repo: ${backupPath}"

            bat """
                if not exist "${backupPath}" mkdir "${backupPath}"
                copy /Y "${XML_PATH}" "${backupPath}\\"
            """

            echo "Backup completed successfully at ${backupPath}"

        } catch (err) {
            echo "Error during backup: ${err}"
            error("Backup failed. Verify XML_PATH and permissions.")
        }
    }

    // -------------------------------
    // Update XML File with Tag Values
    // -------------------------------
    stage('Update XML Tags') {
        try {
            echo "Updating XML tags in file: ${XML_PATH}"

            def tagNamesList  = TAG_NAMES.split(',')
            def tagValuesList = TAG_VALUES.split(',')

            if (tagNamesList.size() != tagValuesList.size()) {
                error("Mismatch: TagNames count (${tagNamesList.size()}) ≠ TagValues count (${tagValuesList.size()})")
            }

            for (int i = 0; i < tagNamesList.size(); i++) {
                def tag = tagNamesList[i].trim()
                def val = tagValuesList[i].trim()
                echo "Updating <${tag}> with value '${val}'"

                bat """
                    powershell -Command "(Get-Content '${XML_PATH}') -replace '<${tag}>.*?</${tag}>', '<${tag}>${val}</${tag}>' | Set-Content '${XML_PATH}'"
                """
            }

            echo "All tags updated successfully."

        } catch (err) {
            echo "Error while updating XML: ${err}"
            error("XML update failed.")
        }
    }

    // -------------------------------
    // Deploy Updated Metadata to Salesforce Org
    // -------------------------------
    stage('Deploy to Salesforce Org') {
        try {
            echo "Deploying only the updated XML file to Salesforce Org: ${ORG_ALIAS}"

            def deployExists = fileExists(XML_PATH)
            if (!deployExists) {
                error "Deployment failed: File not found at ${XML_PATH}"
            }

            if (isUnix()) {
                sh """
                    echo "Deploying ${XML_PATH} to org ${ORG_ALIAS}..."
                    sf project deploy start --target-org ${ORG_ALIAS} --source-dir "${XML_PATH}" --wait 10
                """
            } else {
                bat """
                    echo Deploying ${XML_PATH} to org ${ORG_ALIAS}...
                    sf project deploy start --target-org %OrgAlias% --source-dir "${XML_PATH}" --wait 10
                """
            }

        } catch (err) {
            echo "Deployment failed: ${err}"
            error("Salesforce deployment failed.")
        }
    }
}
