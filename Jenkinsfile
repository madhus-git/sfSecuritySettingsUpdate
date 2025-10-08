// ================================
// Scripted Jenkins Pipeline (Secure JWT Auth via Jenkins Credentials)
// Enhanced: Mandatory Parameters + Multiple Tag Updates + Org URL
// ================================
node {

    // -------------------------------
    // Parameters (Build with Parameters)
    // -------------------------------
    properties([
        parameters([
            string(name: 'OrgAlias', defaultValue: '', description: 'Salesforce Org Alias / Username'),
            string(name: 'OrgUrl', defaultValue: 'https://login.salesforce.com', description: 'Salesforce Org URL (e.g. https://login.salesforce.com or https://test.salesforce.com)'),
            string(name: 'XMLFilePath', defaultValue: '', description: 'Path to XML file to update'),
            string(name: 'TagNames', defaultValue: '', description: 'Comma-separated XML tag names to update (e.g. tag1,tag2)'),
            string(name: 'TagValues', defaultValue: '', description: 'Comma-separated XML tag values (e.g. value1,value2)'),
            string(name: 'BranchName', defaultValue: '', description: 'Git branch to push changes')
        ])
    ])

    // -------------------------------
    // Initialize Variables
    // -------------------------------
    def ORG_ALIAS = params.OrgAlias?.trim()
    def ORG_URL = params.OrgUrl?.trim()
    def XML_PATH = params.XMLFilePath?.trim()
    def TAG_NAMES = params.TagNames?.trim()
    def TAG_VALUES = params.TagValues?.trim()
    def GIT_BRANCH = params.BranchName?.trim()
    def BACKUP_DIR = "backup_${env.BUILD_ID}"
    def xmlFileName = XML_PATH.tokenize('\\\\/').last()
    def backupFile = "${BACKUP_DIR}/${xmlFileName}"

    // Normalize for Windows
    if (!isUnix()) {
        XML_PATH = XML_PATH.replaceAll('/', '\\\\')
        backupFile = backupFile.replaceAll('/', '\\\\')
        BACKUP_DIR = BACKUP_DIR.replaceAll('/', '\\\\')
    }

    try {
        // -------------------------------
        // Mandatory Parameter Validation
        // -------------------------------
        if (!ORG_ALIAS) { error "OrgAlias parameter is mandatory. Please provide a value." }
        if (!ORG_URL) { error "OrgUrl parameter is mandatory. Please provide a value." }
        if (!XML_PATH) { error "XMLFilePath parameter is mandatory. Please provide a value." }
        if (!TAG_NAMES) { error "TagNames parameter is mandatory. Please provide a value." }
        if (!TAG_VALUES) { error "TagValues parameter is mandatory. Please provide a value." }
        if (!GIT_BRANCH) { error "BranchName parameter is mandatory. Please provide a value." }

        // Split multiple tags/values
        def tagList = TAG_NAMES.split(',').collect { it.trim() }
        def valueList = TAG_VALUES.split(',').collect { it.trim() }
        if (tagList.size() != valueList.size()) {
            error "Number of TagNames and TagValues must match. Found ${tagList.size()} tags and ${valueList.size()} values."
        }

        // -------------------------------
        // Checkout Code
        // -------------------------------
        stage('Checkout Code') {
            echo "Checking out code..."
            checkout scm
        }

        // -------------------------------
        // Backup XML
        // -------------------------------
        stage('Create Backup Folder and Backup XML') {
            echo "Creating backup folder: ${BACKUP_DIR}"
            if (isUnix()) {
                sh "mkdir -p \"${BACKUP_DIR}\""
                sh "cp \"${XML_PATH}\" \"${backupFile}\""
            } else {
                bat """
                    if not exist "${BACKUP_DIR}" mkdir "${BACKUP_DIR}"
                    if exist "${XML_PATH}" (
                        copy /Y "${XML_PATH}" "${BACKUP_DIR}\\" >nul
                    ) else (
                        echo XML file not found: ${XML_PATH}
                        exit /b 1
                    )
                """
            }
        }

        // -------------------------------
        // Validate XML Path
        // -------------------------------
        stage('Validate XML Path') {
            echo "Validating XML path..."
            def fileExists = false
            if (isUnix()) {
                fileExists = sh(script: "test -f \"${XML_PATH}\" && echo true || echo false", returnStdout: true).trim() == "true"
            } else {
                fileExists = bat(script: "if exist \"${XML_PATH}\" (echo true) else (echo false)", returnStdout: true).trim().toLowerCase().contains("true")
            }
            if (!fileExists) { error "XML file not found at path: ${XML_PATH}" }
            echo "XML path validated: ${XML_PATH}"
        }

        // -------------------------------
        // Update Multiple Tags in XML
        // -------------------------------
        stage('Update XML Tags') {
            echo "Updating multiple tags in XML..."
            def xmlContent = readFile(XML_PATH)

            for (int i = 0; i < tagList.size(); i++) {
                def tag = tagList[i]
                def value = valueList[i]
                echo "Updating tag <${tag}> → ${value}"
                def pattern = /<${tag}>.*?<\/${tag}>/
                if (!(xmlContent =~ pattern)) {
                    echo "Tag <${tag}> not found in XML, skipping..."
                    continue
                }
                xmlContent = xmlContent.replaceAll(pattern, "<${tag}>${value}</${tag}>")
            }

            writeFile(file: XML_PATH, text: xmlContent)
        }

        // -------------------------------
        // Detect Changes
        // -------------------------------
        stage('Detect Changes in XML') {
            echo "Checking for changes..."
            def changed = false

            if (isUnix()) {
                def diffOutput = sh(script: "diff \"${backupFile}\" \"${XML_PATH}\" || true", returnStdout: true).trim()
                changed = diffOutput ? true : false
            } else {
                def diffOutput = bat(script: "fc \"${backupFile}\" \"${XML_PATH}\" || exit /b 0", returnStdout: true).trim()
                changed = !diffOutput.isEmpty()
            }

            if (!changed) {
                echo "No changes detected. Skipping Git push and deployment."
                currentBuild.result = 'SUCCESS'
                return
            }

            echo "Changes detected."
        }

        // -------------------------------
        // Commit & Push Changes
        // -------------------------------
        stage('Push Changes to GitHub') {
            echo "Committing and pushing changes to branch: ${GIT_BRANCH}"
            if (isUnix()) {
                sh """
                    git config user.email "jenkins@example.com"
                    git config user.name "Jenkins CI"
                    git checkout -B ${GIT_BRANCH}
                    git add "${XML_PATH}"
                    git commit -m "Updated XML tags via Jenkins build #${env.BUILD_ID}" || echo "No changes to commit"
                    git push -u origin ${GIT_BRANCH}
                """
            } else {
                bat """
                    git checkout -B ${GIT_BRANCH}
                    git add "${XML_PATH}"
                    git commit -m "Updated XML tags via Jenkins build #${env.BUILD_ID}" || echo No changes to commit
                    git push -u origin ${GIT_BRANCH}
                """
            }
        }

        // -------------------------------
        // Authenticate Salesforce Org
        // -------------------------------
        stage('Authenticate Org') {
            echo "Authenticating Salesforce Org: ${ORG_ALIAS} using JWT from Jenkins credentials..."

            withCredentials([
                string(credentialsId: 'sfdc-consumer-key', variable: 'CONNECTED_APP_CONSUMER_KEY'),
                string(credentialsId: 'sfdc-username', variable: 'SFDC_USERNAME'),
                file(credentialsId: 'sfdc-jwt-key', variable: 'JWT_KEY_FILE')
            ]) {
                if (isUnix()) {
                    sh """
                        set -x
                        sf org login jwt \
                            --client-id ${CONNECTED_APP_CONSUMER_KEY} \
                            --jwt-key-file ${JWT_KEY_FILE} \
                            --username $SFDC_USERNAME \
                            --alias $ORG_ALIAS \
                            --instance-url ${ORG_URL} | tee auth.log
                    """
                } else {
                    bat """
                        @echo off
                        echo Authenticating Salesforce Org...
                        sf org login jwt ^
                            --client-id %CONNECTED_APP_CONSUMER_KEY% ^
                            --jwt-key-file %JWT_KEY_FILE% ^
                            --username %SFDC_USERNAME% ^
                            --alias %OrgAlias% ^
                            --instance-url ${ORG_URL}
                    """
                }
            }
        }

        // -------------------------------
        // Deploy Updated XML Only
        // -------------------------------
        stage('Deploy to Salesforce Org') {
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
        }

    } catch (err) {
        echo "Error encountered: ${err}"
        currentBuild.result = 'FAILURE'
        throw err
    } finally {
        stage('Clean Workspace') {
            echo "Cleaning workspace..."
            cleanWs()
        }
    }
}
