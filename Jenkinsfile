node {
    try {
        // ===============================
        // 1️⃣ Define Input Parameters
        // ===============================
        properties([
            parameters([
                string(name: 'SETTINGS_FILE_PATTERN', defaultValue: 'Security.settings-meta.xml', description: 'Pattern for settings XML files (supports * wildcard)'),
                string(name: 'UPDATE_KEYS', defaultValue: 'canUsersGrantLoginAccess,enableAdminLoginAsAnyUser', description: 'Comma-separated XML node names to update'),
                string(name: 'UPDATE_VALUES', defaultValue: 'true,false', description: 'Comma-separated values for the XML nodes'),
                string(name: 'ORG_ALIAS', defaultValue: 'devOrg', description: 'Salesforce Org alias for deployment'),
                string(name: 'GIT_BRANCH', defaultValue: 'main', description: 'Git branch for commit')
            ])
        ])

        // ===============================
        // 2️⃣ Checkout Source Code
        // ===============================
        stage('Checkout') {
            checkout scm
        }

        // ===============================
        // 3️⃣ Locate XML Files
        // ===============================
        stage('Locate XML Files') {
            def settingsDir = new File("${env.WORKSPACE}/force-app/main/default/settings")
            if (!settingsDir.exists()) {
                error "Settings directory not found: ${settingsDir.absolutePath}"
            }

            def pattern = params.SETTINGS_FILE_PATTERN.replace(".", "\\.").replace("*", ".*")
            xmlFiles = settingsDir.listFiles().findAll { it.name ==~ pattern }

            if (xmlFiles.isEmpty()) {
                error "No XML files found matching pattern: ${params.SETTINGS_FILE_PATTERN}"
            }

            echo "Found ${xmlFiles.size()} file(s):"
            xmlFiles.each { echo " - ${it.name}" }

            env.XML_FILE_PATHS = xmlFiles.collect { it.path }.join(';')
        }

        // ===============================
        // 4️⃣ Backup XML Files
        // ===============================
        stage('Backup XML Files') {
            xmlFiles = env.XML_FILE_PATHS.split(';').collect { new File(it) }
            xmlFiles.each { f ->
                def backup = new File(f.path + ".bak")
                backup.text = f.text
                echo "Backup created for ${f.name}"
            }
        }

        // ===============================
        // 5️⃣ Update XML Nodes
        // ===============================
        stage('Update XML Files') {
            def keys = params.UPDATE_KEYS.split(',').collect { it.trim() }
            def values = params.UPDATE_VALUES.split(',').collect { it.trim() }
            if (keys.size() != values.size()) error "UPDATE_KEYS and UPDATE_VALUES must have same count"

            def updateMap = [:]
            keys.eachWithIndex { k, i -> updateMap[k] = values[i] }

            xmlFiles.each { f ->
                echo "Updating ${f.name}"
                def xml = new XmlParser().parse(f)

                updateMap.each { k, v ->
                    def node = xml."${k}"
                    if (node && !node.isEmpty()) {
                        node[0].value = v
                        echo "✅ Updated <${k}> to '${v}'"
                    } else {
                        xml.appendNode(k, v)
                        echo "🆕 Added <${k}> = '${v}'"
                    }
                }

                // Write back
                def writer = new FileWriter(f)
                def printer = new XmlNodePrinter(new PrintWriter(writer))
                printer.setPreserveWhitespace(true)
                printer.print(xml)
                writer.close()

                // Validate
                def xmlAfter = new XmlParser().parse(f)
                updateMap.each { k, v ->
                    def actual = xmlAfter."${k}" ? xmlAfter."${k}"[0].text() : null
                    if (actual != v) {
                        error "❌ Validation failed for ${k} in ${f.name}. Expected '${v}', found '${actual}'"
                    }
                }

                echo "✅ Validation passed for ${f.name}"
            }
        }

        // ===============================
        // 6️⃣ Commit to Git
        // ===============================
        stage('Commit Updates') {
            def commitCmd = """
                git config user.email "jenkins@yourdomain.com"
                git config user.name "Jenkins"
                git checkout ${params.GIT_BRANCH}
                git add force-app/main/default/settings
                git commit -m "Updated settings XML automatically via Jenkins"
                git push origin ${params.GIT_BRANCH}
            """

            if (isUnix()) {
                sh commitCmd
            } else {
                bat commitCmd
            }
            echo "✅ Changes committed to Git successfully."
        }

        // ===============================
        // 7️⃣ Deploy to Salesforce Org
        // ===============================
        /*stage('Deploy to Org') {
            def deployCmd = "sf project deploy start --source-dir force-app/main/default/settings --target-org ${params.ORG_ALIAS} --ignore-conflicts --wait 10 --verbose"
            def deployResult = isUnix() ? sh(script: deployCmd, returnStatus: true) : bat(script: deployCmd, returnStatus: true)
            if (deployResult != 0) {
                error "Deployment failed to ${params.ORG_ALIAS}"
            }
            echo "🚀 Deployment succeeded to ${params.ORG_ALIAS}"
        }*/

        echo "🎉 Pipeline completed successfully for org: ${params.ORG_ALIAS}"

    } catch (err) {
        // ===============================
        // 8️⃣ Rollback on Failure
        // ===============================
        stage('Rollback Changes') {
            echo "⚠️ Rolling back XML changes..."
            if (env.XML_FILE_PATHS) {
                env.XML_FILE_PATHS.split(';').each { path ->
                    def f = new File(path)
                    def backup = new File(path + ".bak")
                    if (backup.exists()) {
                        f.text = backup.text
                        echo "Restored backup for ${f.name}"
                    }
                }
            }
        }
        currentBuild.result = 'FAILURE'
        throw err
    }
}
