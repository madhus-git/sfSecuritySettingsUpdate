node {
    try {
        // ===============================
        // 1️⃣ Define build parameters
        // ===============================
        properties([
            parameters([
                string(name: 'SETTINGS_FILE_PATTERN', defaultValue: 'Security.settings-meta.xml', description: 'Settings XML file pattern (supports * wildcard)'),
                string(name: 'UPDATE_KEYS', defaultValue: 'canUsersGrantLoginAccess,enableAdminLoginAsAnyUser', description: 'Comma-separated XML nodes to update'),
                string(name: 'UPDATE_VALUES', defaultValue: 'true,false', description: 'Comma-separated values for the nodes'),
                string(name: 'DEPLOY_ORG_ALIASES', defaultValue: 'devOrg;sitOrg', description: 'Semicolon-separated Salesforce org aliases to deploy to'),
                string(name: 'GIT_BRANCH', defaultValue: 'main', description: 'Git branch to commit updates')
            ])
        ])

        // ===============================
        // 2️⃣ Checkout the code
        // ===============================
        stage('Checkout') {
            checkout scm
        }

        // ===============================
        // 3️⃣ Locate XML Files
        // ===============================
        stage('Locate XML Files') {
            def settingsDir = new File("${env.WORKSPACE}/force-app/main/default/settings")
            if (!settingsDir.exists()) error "Settings directory not found: ${settingsDir}"

            def patternRegex = params.SETTINGS_FILE_PATTERN.replace(".", "\\.").replace("*", ".*")
            xmlFiles = settingsDir.listFiles().findAll { it.name ==~ patternRegex }

            if (xmlFiles.size() == 0) error "No files found for pattern: ${params.SETTINGS_FILE_PATTERN}"

            env.XML_FILE_PATHS = xmlFiles.collect { it.path }.join(';')
            echo "Found ${xmlFiles.size()} file(s) to update."
        }

        // ===============================
        // 4️⃣ Backup original files
        // ===============================
        stage('Backup XML Files') {
            xmlFiles = env.XML_FILE_PATHS.split(';').collect { new File(it) }
            xmlFiles.each { f ->
                def backupFile = new File(f.path + ".bak")
                backupFile.text = f.text
                println "Backup created: ${backupFile.path}"
            }
        }

        // ===============================
        // 5️⃣ Update XML Files
        // ===============================
        stage('Update XML') {
            def keys = params.UPDATE_KEYS.split(',')
            def values = params.UPDATE_VALUES.split(',')
            if (keys.size() != values.size()) error "UPDATE_KEYS and UPDATE_VALUES must have same number of items"

            def updateMap = [:]
            keys.eachWithIndex { k, i -> updateMap[k] = values[i] }

            xmlFiles.each { f ->
                println "Updating XML file: ${f.path}"
                def xml = new XmlParser().parse(f)

                updateMap.each { k, v ->
                    def node = xml."${k}"
                    if (node) {
                        node[0].value = v
                        println "Updated ${k} -> ${v}"
                    } else {
                        xml.appendNode(k, v)
                        println "Added node ${k} -> ${v}"
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
                keys.each { k ->
                    def nodeValue = xmlAfter."${k}" ? xmlAfter."${k}"[0].text() : null
                    if (nodeValue != updateMap[k]) error "Validation failed for ${k} in ${f.path}. Expected: ${updateMap[k]}, Found: ${nodeValue}"
                }
                println "Validation passed for file: ${f.path}"
            }
        }

        // ===============================
        // 6️⃣ Deploy to multiple Salesforce Orgs
        // ===============================
        stage('Deploy to Orgs') {
            def orgAliases = params.DEPLOY_ORG_ALIASES.split(';')
            xmlFiles = env.XML_FILE_PATHS.split(';').collect { new File(it) }
            def filesToDeploy = xmlFiles.collect { it.path }.join(' ')

            orgAliases.each { orgAlias ->
                echo "Deploying to org: ${orgAlias}"
                def deployResult = bat(script: "sfdx force:source:deploy -p ${filesToDeploy} -u ${orgAlias} --wait 10 --testlevel NoTestRun", returnStatus: true)
                if (deployResult != 0) {
                    error "Deployment failed for org: ${orgAlias}"
                }
                echo "Deployment succeeded for org: ${orgAlias}"
            }
        }

        // ===============================
        // 7️⃣ Commit updated XML to Git
        // ===============================
        stage('Commit Updates') {
            bat """
                git config user.email "jenkins@yourdomain.com"
                git config user.name "Jenkins"
                git checkout ${params.GIT_BRANCH}
                git add ${env.XML_FILE_PATHS.replace(';',' ')}
                git commit -m "Updated settings XML via Jenkins build for multiple orgs"
                git push origin ${params.GIT_BRANCH}
            """
        }

        echo "Pipeline completed successfully for all orgs!"

    } catch (err) {
        // ===============================
        // 8️⃣ Rollback XML changes if anything fails
        // ===============================
        stage('Rollback Changes') {
            echo "Rolling back XML changes..."
            if (env.XML_FILE_PATHS) {
                xmlFiles = env.XML_FILE_PATHS.split(';').collect { new File(it) }
                xmlFiles.each { f ->
                    def backupFile = new File(f.path + ".bak")
                    if (backupFile.exists()) {
                        f.text = backupFile.text
                        println "Restored backup: ${f.path}"
                    }
                }
            }
        }

        currentBuild.result = 'FAILURE'
        throw err
    }
}
