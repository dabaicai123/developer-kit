package ${package.Service}

import ${package.Entity}.${entity}
import ${superServiceClassPackage}
<#if swagger>
import io.swagger.v3.oas.annotations.tags.Tag
</#if>

/**
 * <p>${table.comment} service interface</p>
 *
 * <p>Defines business logic interfaces related to ${table.comment}, including CRUD operations.
 * This interface follows Domain-Driven Design (DDD) principles, encapsulating core business logic of the ${table.comment} domain.</p>
 *
 * <p>Primary responsibilities:
 * <ul>
 *   <li>Create and save ${table.comment}</li>
 *   <li>Query ${table.comment} information (including conditional queries)</li>
 *   <li>Update ${table.comment} information</li>
 *   <li>Delete ${table.comment}</li>
<#if customMethods??>
<#list customMethods as method>
 *   <li>${method.description}</li>
</#list>
</#if>
 * </ul>
 * </p>
 *
 * @author ${author}
 * @since ${date}
 */
<#if swagger>
@Tag(name = "${table.comment} Management", description = "${table.comment} service interface")
</#if>
interface ${table.serviceName} : ${superServiceClass}<${entity}> {
<#if customMethods??>

## ----------  BEGIN Custom methods  ----------
<#list customMethods as method>
    /**
     * <p>${method.description}</p>
     *
     * <p>${method.detailDescription}</p>
     *
<#list method.parameters as param>
     * @param ${param.name} ${param.type} ${param.description}
</#list>
     * @return ${method.returnType} ${method.returnDescription}
<#if method.exceptions??>
<#list method.exceptions as exception>
     * @exception ${exception.type} ${exception.description}
</#list>
</#if>
     */
    fun ${method.name}(<#list method.parameters as param>${param.name}: ${param.type}<#if param_has_next>, </#if></#list>): ${method.returnType}
</#list>
## ----------  END Custom methods  ----------
</#if>
}