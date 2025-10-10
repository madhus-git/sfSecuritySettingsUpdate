// ================================
// Scripted Jenkins Pipeline (Secure JWT Auth via Jenkins Credentials)
// Enhanced: Backup under /backups, Show Old/New Tag Values, Org URL support
// ================================
node {

    properties([
        parameters([
            string(name: 'OrgAlias', defaultValue: '', description: '* Salesforce Org Alias / Username'),
            string(name: 'OrgUrl', defaultValue: 'https://login.salesforce.com', description: '* Salesforce Org URL'),
            string(name: 'XMLFilePath', defaultValue: '', description: '* Path to XML file to update'),
            string(name: 'TagNames', defaultValue: '', description: '* Comma-separated XML tag names (e.g. tag1,tag2)'),
            string(name: 'TagValues', defaultValue: '', description: '* Comma-separated tag values (e.g. value1,value2)'),
            string(name: 'BranchName', defaultValue: '', description: '* Git branch to push changes')
        ])
    ])

    def ORG_ALIAS = params.OrgAlias?.trim()
    def ORG_URL = params.OrgUrl?.trim()
    def XML_PATH = params.XMLFilePath?.trim()
    def TAG_NAMES = params.TagNames?.trim()
    def TAG_VALUES = params.TagValues?.trim()
    def GIT_BRANCH = params.BranchName?.trim()
    def BACKUP_DIR = "backups/backup_${env.BUILD_ID}"
    def xmlFileName = XML_PATH.tokenize('/').last()
    def backupFile = "${BACKUP_DIR}/${xmlFileName}"

    try {

        // -------------------------------
        // Validate mandatory params
        // -------------------------------
        if (!ORG_ALIAS) error "OrgAlias is mandatory"
        if (!ORG_URL) error "OrgUrl is mandatory"
        if (!XML_PATH) error "XMLFilePath is mandatory"
        if (!TAG_NAMES) error "TagNames is mandatory"
        if (!TAG_VALUES) error "TagValues is mandatory"
        if (!GIT_BRANCH) error "BranchName is mandatory"

        def tagList = TAG_NAMES.split(',').collect { it.trim() }
        def valueList = TAG_VALUES.split(',').collect { it.trim() }
        if (tagList.size() != valueList.size()) {
            error "Number of TagNames (${tagList.size()}) must match TagValues (${valueList.size()})"
        }

        stage('Checkout Code') {
            echo "Checking out source code..."
            checkout scm
        }

        // -------------------------------
        // Create centralized backup folder under /backups
        // -------------------------------
        stage('Backup XML to /backups folder') {
            echo "Creating backup folder under repo: ${BACKUP_DIR}"
            if (isUnix()) {
                sh """
                    mkdir -p "${BACKUP_DIR}"
                    cp "${XML_PATH}" "${backupFile}"
                """
            } else {
                bat """
                    if not exist "${BACKUP_DIR}" mkdir "${BACKUP_DIR}"
                    copy /Y "${XML_PATH}" "${backupFile}" >nul
                """
            }
            echo "✅ Backup created at: ${backupFile}"
        }

        // -------------------------------
        // Read original XML and update tags
        // -------------------------------
        stage('Update XML Tags and Display Changes') {
            def xmlContent = readFile(XML_PATH)
            def originalXml = xmlContent

            for (int i = 0; i < tagList.size(); i++) {
                def tag = tagList[i]
                def newValue = valueList[i]
                def pattern = /<${tag}>(.*?)<\/${tag}>/
                def matcher = (xmlContent =~ pattern)
                if (matcher) {
                    def oldValue = matcher[0][1]
                    echo "🔸 Tag: <${tag}> | Old Value: ${oldValue} | New Value: ${newValue}"
                    xmlContent = xmlContent.replaceAll(pattern, "<${tag}>${newValue}</${tag}>")
                } else {
                    echo "⚠️ Tag <${tag}> not found in XML, skipping..."
                }
            }

            writeFile(file: XML_PATH, text: xmlContent)
        }

        // -------------------------------
        // Compare with backup and detect changes
        // -------------------------------
        stage('Detect XML Changes') {
            def diffOutput = ""
            if (isUnix()) {
                diffOutput = sh(script: "diff \"${backupFile}\" \"${XML_PATH}\" || true", returnStdout: true).trim()
            } else {
                diffOutput = bat(script: "fc \"${backupFile}\" \"${XML_PATH}\" || exit /b 0", returnStdout: true).trim()
            }

            if (!diffOutput) {
                echo "✅ No changes detected — skipping commit and deploy."
                currentBuild.result = 'SUCCESS'
                return
            }

            echo "🟡 Changes detected between original and updated XML:"
            echo "${diffOutput.take(1000)}" // limit for readability
        }

        // -------------------------------
        // Commit and Push to GitHub (includes backups)
        // -------------------------------
        stage('Push Changes to GitHub') {
            echo "Committing XML & backup files to branch: ${GIT_BRANCH}"
            if (isUnix()) {
                sh """
                    git config user.email "jenkins@example.com"
                    git config user.name "Jenkins CI"
                    git checkout -B ${GIT_BRANCH}
                    git add "${XML_PATH}" "${BACKUP_DIR}/${xmlFileName}"
                    git commit -m "Updated ${xmlFileName} and backed up under /backups via Jenkins build #${env.BUILD_ID}" || echo "No changes"
                    git push -u origin ${GIT_BRANCH}
                """
            } else {
                bat """
                    git config user.email "jenkins@example.com"
                    git config user.name "Jenkins CI"
                    git checkout -B ${GIT_BRANCH}
                    git add "${XML_PATH}" "${BACKUP_DIR}\\${xmlFileName}"
                    git commit -m "Updated ${xmlFileName} and backed up under /backups via Jenkins build #${env.BUILD_ID}" || echo No changes
                    git push -u origin ${GIT_BRANCH}
                """
            }
            echo "✅ Backup & updated XML pushed to GitHub branch: ${GIT_BRANCH}"
            echo "📁 View backups here: https://github.com/madhus-git/sfSecuritySettingsUpdate/tree/${GIT_BRANCH}/backups"
        }

        // -------------------------------
        // Salesforce authentication and deploy
        // -------------------------------
        stage('Authenticate & Deploy') {
            echo "Authenticating Salesforce Org: ${ORG_ALIAS}"
            withCredentials([
                string(credentialsId: 'sfdc-consumer-key', variable: 'CONNECTED_APP_CONSUMER_KEY'),
                string(credentialsId: 'sfdc-username', variable: 'SFDC_USERNAME'),
                file(credentialsId: 'sfdc-jwt-key', variable: 'JWT_KEY_FILE')
            ]) {
                if (isUnix()) {
                    sh """
                        sf org login jwt \
                            --client-id ${CONNECTED_APP_CONSUMER_KEY} \
                            --jwt-key-file ${JWT_KEY_FILE} \
                            --username ${SFDC_USERNAME} \
                            --alias ${ORG_ALIAS} \
                            --instance-url ${ORG_URL}
                    """
                } else {
                    bat """
                        sf org login jwt ^
                            --client-id %CONNECTED_APP_CONSUMER_KEY% ^
                            --jwt-key-file %JWT_KEY_FILE% ^
                            --username %SFDC_USERNAME% ^
                            --alias %OrgAlias% ^
                            --instance-url ${ORG_URL}
                    """
                }
            }

            echo "🚀 Deploying updated XML file to Salesforce Org: ${ORG_ALIAS}"
            if (isUnix()) {
                sh "sf project deploy start --target-org ${ORG_ALIAS} --source-dir \"${XML_PATH}\" --wait 10"
            } else {
                bat "sf project deploy start --target-org %OrgAlias% --source-dir \"${XML_PATH}\" --wait 10"
            }
        }

    } catch (err) {
        echo "❌ Error encountered: ${err}"
        currentBuild.result = 'FAILURE'
        throw err
    } finally {
        stage('Clean Workspace') {
            echo "🧹 Cleaning workspace..."
            cleanWs()
        }
    }
}
