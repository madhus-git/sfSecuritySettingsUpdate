node {
    try {
        // ==================================================
        // 1️⃣ Parameters
        // ==================================================
        properties([
            parameters([
                string(name: 'ORG_ALIAS', defaultValue: 'dev', description: 'Salesforce Org alias'),
                text(name: 'UPDATE_MAP', defaultValue: 'canUsersGrantLoginAccess=false\nenableAdminLoginAsAnyUser=true', description: 'key=value pairs (one per line)')
            ])
        ])

        // ==================================================
        // 2️⃣ Checkout Source Code
        // ==================================================
        stage('Checkout') {
            echo "📦 Checking out source code..."
            checkout scm
        }

        // ==================================================
        // 3️⃣ Update XML Files
        // ==================================================
        stage('Update XML Files') {
            echo "🛠 Updating XML files under force-app/main/default/settings..."

            def xmlDir = "force-app/main/default/settings"
            def isWindows = !isUnix()

            // Convert key=value text to map
            def updateMap = [:]
            params.UPDATE_MAP.split("\n").each { line ->
                def parts = line.trim().split("=")
                if (parts.size() == 2) {
                    updateMap[parts[0].trim()] = parts[1].trim()
                }
            }

            // Get all .xml files
            def files = []
            if (isWindows) {
                files = bat(
                    script: 'powershell -Command "Get-ChildItem -Path \'' + xmlDir + '\' -Filter *.xml | ForEach-Object { $_.FullName }"',
                    returnStdout: true
                ).trim().split("\\r?\\n")
            } else {
                files = sh(
                    script: "find ${xmlDir} -type f -name '*.xml'",
                    returnStdout: true
                ).trim().split("\\r?\\n")
            }

            // Update each XML file
            files.each { filePath ->
                def content = readFile(file: filePath)
                updateMap.each { key, value ->
                    def oldPattern = "<${key}>.*?</${key}>"
                    def newPattern = "<${key}>${value}</${key}>"
                    if (content =~ oldPattern) {
                        content = content.replaceAll(oldPattern, newPattern)
                        echo "✅ Updated ${key} = ${value} in ${filePath}"
                    } else {
                        echo "⚠️ Tag ${key} not found in ${filePath}, adding it..."
                        def insertIndex = content.lastIndexOf("</")
                        if (insertIndex > 0) {
                            content = content.substring(0, insertIndex) + "<${key}>${value}</${key}>\n" + content.substring(insertIndex)
                        }
                    }
                }
                writeFile(file: filePath, text: content)
            }
        }

        // ==================================================
        // 4️⃣ Validate XML Updates
        // ==================================================
        stage('Validate Updates') {
            echo "🔍 Validating XML updates..."
            def xmlDir = "force-app/main/default/settings"
            def isWindows = !isUnix()
            def failed = false

            def files = []
            if (isWindows) {
                files = bat(
                    script: 'powershell -Command "Get-ChildItem -Path \'' + xmlDir + '\' -Filter *.xml | ForEach-Object { $_.FullName }"',
                    returnStdout: true
                ).trim().split("\\r?\\n")
            } else {
                files = sh(
                    script: "find ${xmlDir} -type f -name '*.xml'",
                    returnStdout: true
                ).trim().split("\\r?\\n")
            }

            files.each { filePath ->
                def content = readFile(file: filePath)
                params.UPDATE_MAP.split("\n").each { line ->
                    def (key, value) = line.trim().tokenize("=")
                    if (!content.contains("<${key}>${value}</${key}>")) {
                        echo "❌ Validation failed for ${key} in ${filePath}"
                        failed = true
                    }
                }
            }

            if (failed) {
                error("❌ XML validation failed — some values not updated correctly.")
            } else {
                echo "✅ All XML values validated successfully."
            }
        }

        // ==================================================
        // 5️⃣ Commit Updated Files
        // ==================================================
        stage('Commit to Git') {
            echo "💾 Committing changes to Git..."
            if (isWindows) {
                bat '''
                    git config user.email "jenkins@local"
                    git config user.name "Jenkins"
                    git add force-app\\main\\default\\settings\\*.xml
                    git commit -m "Automated XML update via Jenkins pipeline" || echo "⚠️ No changes to commit"
                    git push origin HEAD:main || echo "⚠️ Push skipped"
                '''
            } else {
                sh '''
                    git config user.email "jenkins@local"
                    git config user.name "Jenkins"
                    git add force-app/main/default/settings/*.xml
                    git commit -m "Automated XML update via Jenkins pipeline" || echo "⚠️ No changes to commit"
                    git push origin HEAD:main || echo "⚠️ Push skipped"
                '''
            }
        }

        // ==================================================
        // 6️⃣ Deploy to Salesforce Org
        // ==================================================
        /*stage('Deploy to Org') {
            echo "🚀 Deploying to Salesforce Org: ${params.ORG_ALIAS}"
            if (isWindows) {
                bat "sf project deploy start --source-dir force-app --target-org ${params.ORG_ALIAS} --ignore-warnings --verbose"
            } else {
                sh "sf project deploy start --source-dir force-app --target-org ${params.ORG_ALIAS} --ignore-warnings --verbose"
            }
        }*/

        echo "🎉 Pipeline completed successfully for org: ${params.ORG_ALIAS}"

    } catch (err) {
        echo "❌ Error: ${err.message}"
        currentBuild.result = 'FAILURE'
        throw err
    }
}
