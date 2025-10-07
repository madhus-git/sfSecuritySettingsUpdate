node {
    try {
        // ========================================================
        // 1️⃣ Define Build Parameters
        // ========================================================
        properties([
            parameters([
                string(name: 'SETTINGS_FILE_PATTERN', defaultValue: 'Security.settings-meta.xml', description: 'Settings XML file pattern (supports * wildcard)'),
                string(name: 'UPDATE_KEYS', defaultValue: 'canUsersGrantLoginAccess,enableAdminLoginAsAnyUser', description: 'Comma-separated XML nodes to update'),
                string(name: 'UPDATE_VALUES', defaultValue: 'true,false', description: 'Comma-separated values for the nodes'),
                string(name: 'DEPLOY_ORG_ALIASES', defaultValue: 'devOrg;sitOrg', description: 'Semicolon-separated Salesforce org aliases to deploy to'),
                string(name: 'GIT_BRANCH', defaultValue: 'main', description: 'Git branch to commit updates')
            ])
        ])

        // ========================================================
        // 2️⃣ Checkout Code
        // ========================================================
        stage('Checkout') {
            checkout scm
        }

        // ========================================================
        // 3️⃣ Locate XML Files
        // ========================================================
        stage('Locate XML Files') {
            def settingsDir = new File("${env.WORKSPACE}/force-app/main/default/settings")
            if (!settingsDir.exists()) error "Settings directory not found: ${settingsDir}"

            def patternRegex = params.SETTINGS_FILE_PATTERN.replace(".", "\\.").replace("*", ".*")
            xmlFiles = settingsDir.listFiles().findAll { it.name ==~ patternRegex }

            if (xmlFiles.isEmpty()) error "No files found for pattern: ${params.SETTINGS_FILE_PATTERN}"

            env.XML_FILE_PATHS = xmlFiles.collect { it.path }.join(';')
            echo "Found ${xmlFiles.size()} file(s) to update."
        }

        // ========================================================
        // 4️⃣ Backup Original Files
        // ========================================================
        stage('Backup XML Files') {
            xmlFiles = env.XML_FILE_PATHS.split(';').collect { new File(it) }
            xmlFiles.each { f ->
                def backupFile = new File(f.path + ".bak")
                backupFile.text = f.text
                echo "Backup created: ${backupFile.path}"
            }
        }

        // ========================================================
        // 5️⃣ Update XML Files
        // ========================================================
        stage('Update XML') {
            def keys = params.UPDATE_KEYS.split(',')
            def values = params.UPDATE_VALUES.split(',')
            if (keys.size() != values.size()) error "UPDATE_KEYS and UPDATE_VALUES count mismatch"

            def updateMap = [:]
            keys.eachWithIndex { k, i -> updateMap[k.trim()] = values[i].trim() }

            xmlFiles.each { f ->
                echo "Updating XML file: ${f.path}"
                def xml = new XmlParser().parse(f)

                updateMap.each { k, v ->
                    def node = xml."${k}"
                    if (node && !node.isEmpty()) {
                        node[0].value = v
                        echo "Updated ${k} -> ${v}"
                    } else {
                        xml.appendNode(k, v)
                        echo "Added node ${k} -> ${v}"
                    }
                }

                // Write back XML
                def writer = new FileWriter(f)
                def printer = new XmlNodePrinter(new PrintWriter(writer))
                printer.setPreserveWhitespace(true)
                printer.print(xml)
                writer.close()

                // Validation
                def xmlAfter = new XmlParser().parse(f)
                updateMap.each { k, v ->
                    def currentVal = xmlAfter."${k}" ? xmlAfter."${k}"[0].text() : null
                    if (currentVal != v) error "Validation failed for ${k} in ${f.name}. Expected: ${v}, Found: ${currentVal}"
                }
                echo "Validation passed for: ${f.name}"
            }
        }

        // ========================================================
        // 6️⃣ Deploy to Multiple Orgs
        // ========================================================
        stage('Deploy to Orgs') {
            def orgAliases = params.DEPLOY_ORG_ALIASES.split(';')
            def xmlPaths = env.XML_FILE_PATHS.split(';').collect { it.trim() }.join(' ')
            orgAliases.each { orgAlias ->
                echo "Deploying to org: ${orgAlias}"

                def deployCmd = "sf project deploy start --source-dir force-app/main/default/settings --target-org ${orgAlias} --ignore-conflicts --wait 10 --verbose"

                def result = isUnix() ? sh(script: deployCmd, returnStatus: true) : bat(script: deployCmd, returnStatus: true)
                if (result != 0) {
                    error "Deployment failed for org: ${orgAlias}"
                } else {
                    echo "Deployment succeeded for org: ${orgAlias}"
                }
            }
        }

        // ========================================================
        // 7️⃣ Commit Updated XML to Git
        // ========================================================
        stage('Commit Updates') {
            def commitCmd = """
                git config user.email "jenkins@yourdomain.com"
                git config user.name "Jenkins"
                git checkout ${params.GIT_BRANCH}
                git add ${env.XML_FILE_PATHS.replace(';', ' ')}
                git commit -m "Updated settings XML automatically via Jenkins"
                git push origin ${params.GIT_BRANCH}
            """

            if (isUnix()) {
                sh commitCmd
            } else {
                bat commitCmd
            }
        }

        echo "✅ Pipeline completed successfully for all orgs!"

    } catch (err) {
        // ========================================================
        // 8️⃣ Rollback if Failure
        // ========================================================
        stage('Rollback Changes') {
            echo "Rolling back XML changes..."
            if (env.XML_FILE_PATHS) {
                xmlFiles = env.XML_FILE_PATHS.split(';').collect { new File(it) }
                xmlFiles.each { f ->
                    def backupFile = new File(f.path + ".bak")
                    if (backupFile.exists()) {
                        f.text = backupFile.text
                        echo "Restored backup: ${f.path}"
                    }
                }
            }
        }
        currentBuild.result = 'FAILURE'
        throw err
    }
}
