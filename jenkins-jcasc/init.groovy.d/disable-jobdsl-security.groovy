import javaposse.jobdsl.plugin.GlobalJobDslSecurityConfiguration
import jenkins.model.Jenkins

// The static .get() method was removed in newer versions of the Job DSL plugin.
// The correct way to get the configuration is to look it up as an extension.
def jenkins = Jenkins.get()
def config = jenkins.getExtensionList(GlobalJobDslSecurityConfiguration.class).get(0)

config.useScriptSecurity = false

config.save()

println "Job DSL Script Security Disabled"