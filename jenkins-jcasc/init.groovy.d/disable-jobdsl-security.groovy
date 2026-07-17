import javaposse.jobdsl.plugin.GlobalJobDslSecurityConfiguration

def config = GlobalJobDslSecurityConfiguration.get()

config.useScriptSecurity = false

config.save()

println "Job DSL Script Security Disabled"