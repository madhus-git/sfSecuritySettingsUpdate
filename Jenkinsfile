// ================================
// Scripted Jenkins Pipeline (Cross-Platform Safe)
// ================================
node {

    // -------------------------------
    // Parameters (Build with Parameters)
    // -------------------------------
    properties([
        parameters([
            string(name: 'OrgAlias', defaultValue: '', description: 'Salesforce Org Alias'),
            string(name: 'XMLFilePath', defaultValue: '', description: 'Path to XML file to update'),
            string(name: 'TagName', defaultValue: '', description: 'XML Tag to update'),
            string(name: 'TagValue', defaultValue: '', description: 'New value for XML Tag'),
            string(name: 'BranchName', defaultValue: 'devOrg', description: 'Git branch to push changes')
        ])
    ])

    // -------------------------------
    // Initialize Variables
    // -------------------------------
    def ORG_ALIAS = params.OrgAlias?.trim()
    def XML_PATH = params.XMLFilePath?.trim()
    def TAG_NAME = params.TagName?.trim()
    def TAG_VALUE = params.TagValue?.trim()
    def GIT_BRANCH = params.BranchName?.trim() ?: 'devOrg'
    def BACKUP_DIR = "backup_${env.BUILD_ID}"
    def xmlFileName = XML_PATH.tokenize('\\\\/').last()
    def backupFile = "${BACKUP_DIR}/${xmlFileName}"

    try {

        // -------------------------------
        // Early Parameter Validation
        // -------------------------------
        if (!ORG_ALIAS) { error "OrgAlias parameter is empty." }
        if (!XML_PATH) { error "XMLFilePath parameter is empty." }
        if (!TAG_NAME) { error "TagName parameter is empty." }
        if (!TAG_VALUE) { error "TagValue parameter is empty." }

        stage('Checkout Code') {
            echo "Checking out code..."
            checkout scm
        }

        stage('Create Backup Folder and Backup XML') {
            echo "Creating backup folder: ${BACKUP_DIR}"
            if (isUnix()) {
                sh "mkdir -p \"${BACKUP_DIR}\""
                sh "cp \"${XML_PATH}\" \"${BACKUP_DIR}/\""
            } else {
                bat """
                    if not exist "${BACKUP_DIR}" mkdir "${BACKUP_DIR}"
                    if exist "${XML_PATH}" (
                        copy /Y "${XML_PATH}" "${BACKUP_DIR}\\"
                    ) else (
                        echo XML file not found: ${XML_PATH}
                        exit /b 1
                    )
                """
            }
        }

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

        stage('Update Security Settings') {
            echo "Updating tag <${TAG_NAME}> in XML to value: ${TAG_VALUE}"
            def xmlContent = readFile(XML_PATH)
            def pattern = /<${TAG_NAME}>.*?<\/${TAG_NAME}>/
            if (!(xmlContent =~ pattern)) { error "Tag <${TAG_NAME}> not found in XML" }
            xmlContent = xmlContent.replaceAll(pattern, "<${TAG_NAME}>${TAG_VALUE}</${TAG_NAME}>")
            writeFile(file: XML_PATH, text: xmlContent)
        }

        stage('Detect Changes in XML') {
            echo "Checking for changes..."
            if (isUnix()) {
                def diffOutput = sh(script: "diff \"${backupFile}\" \"${XML_PATH}\" || true", returnStdout: true).trim()
                if (!diffOutput) {
                    echo "No changes detected. Skipping Git push and deployment."
                    currentBuild.result = 'SUCCESS'
                    return
                }
            } else {
                // Ensure backup file exists
                bat """
                    if not exist "${BACKUP_DIR}\\${xmlFileName}" (
                        echo Backup file not found: ${BACKUP_DIR}\\${xmlFileName}
                        exit /b 1
                    )
                """
                def diffOutput = bat(script: "fc \"${BACKUP_DIR}\\${xmlFileName}\" \"${XML_PATH}\"", returnStdout: true).trim()
                if (!diffOutput) {
                    echo "No changes detected. Skipping Git push and deployment."
                    currentBuild.result = 'SUCCESS'
                    return
                }
            }
            echo "Changes detected."
        }

        stage('Validate Updated Values') {
            echo "Validating updated XML values..."
            def xmlContent = readFile(XML_PATH)
            if (!xmlContent.contains("<${TAG_NAME}>${TAG_VALUE}</${TAG_NAME}>")) {
                error "Validation failed: Tag <${TAG_NAME}> was not updated correctly"
            }
            echo "Validation passed."
        }

        stage('Push Changes to GitHub') {
            echo "Committing and pushing changes to GitHub..."
            if (isUnix()) {
                sh """
                    git config user.email "jenkins@example.com"
                    git config user.name "Jenkins CI"
                    git add "${XML_PATH}"
                    git commit -m "Updated <${TAG_NAME}> to ${TAG_VALUE} via Jenkins build #${env.BUILD_ID}" || echo "No changes to commit"
                    git push origin ${GIT_BRANCH}
                """
            } else {
                bat """
                    git add "${XML_PATH}"
                    git commit -m "Updated <${TAG_NAME}> to ${TAG_VALUE} via Jenkins build #${env.BUILD_ID}" || echo No changes to commit
                    git push origin ${GIT_BRANCH}
                """
            }
        }

        stage('Deploy to Salesforce Org') {
            echo "Deploying to Salesforce Org: ${ORG_ALIAS}"
            if (isUnix()) {
                sh "sf deploy metadata --target-org ${ORG_ALIAS} --manifest ./manifest/package.xml"
            } else {
                bat "sf deploy metadata --target-org ${ORG_ALIAS} --manifest .\\manifest\\package.xml"
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
