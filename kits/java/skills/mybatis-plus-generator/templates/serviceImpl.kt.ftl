package ${package.ServiceImpl}

import ${package.Entity}.${entity}
import ${package.Mapper}.${table.mapperName}
import ${package.Service}.${table.serviceName}
import ${superServiceImplClassPackage}
import org.springframework.stereotype.Service
<#if swagger>
import io.swagger.v3.oas.annotations.tags.Tag
</#if>

/**
 * <p>${table.comment} service implementation class</p>
 *
 * <p>Implements the ${table.serviceName} interface, providing business logic implementation related to ${table.comment}.
 * This class handles core business operations such as ${table.comment} creation, query, update, and deletion.</p>
 *
 * <p>Primary functions:
 * <ul>
 *   <li>Create ${table.comment}: including data validation and business rule checks</li>
 *   <li>Query ${table.comment}: supports query by ID, conditional query, and paginated query</li>
 *   <li>Update ${table.comment}: supports partial field updates and business rule validation</li>
 *   <li>Delete ${table.comment}: cascade deletes related data</li>
<#if customMethods??>
<#list customMethods as method>
 *   <li>${method.description}: ${method.detailDescription}</li>
</#list>
</#if>
 * </ul>
 * </p>
 *
 * @author ${author}
 * @since ${date}
 */
<#if swagger>
@Tag(name = "${table.comment} Management", description = "${table.comment} service implementation")
</#if>
@Service
class ${table.serviceImplName} : ${superServiceImplClass}<${table.mapperName}, ${entity}>(), ${table.serviceName} {

<#if customMethods??>
<#-- BEGIN Custom method implementations -->
<#list customMethods as method>
    /**
     * <p>${method.description}</p>
     *
     * <p>${method.detailDescription}</p>
     *
     * <p>Implementation logic:
     * <ol>
     *   <li>Parameter validation: Check the validity of input parameters</li>
     *   <li>Business logic: Execute specific business operations</li>
     *   <li>Data persistence: Call the Mapper layer for data operations</li>
     *   <li>Result return: Return the processing result</li>
     * </ol>
     * </p>
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
    override fun ${method.name}(<#list method.parameters as param>${param.name}: ${param.type}<#if param_has_next>, </#if></#list>): ${method.returnType} {
<#if method.parameters??>
<#list method.parameters as param>
        requireNotNull(${param.name}) { "${param.description} cannot be empty" }
<#if param.type == "String">
        require(${param.name}.isNotEmpty()) { "${param.description} cannot be empty" }
</#if>
</#list>
</#if>
        TODO("Not implemented: ${method.name}")
    }
</#list>
<#-- END Custom method implementations -->
</#if>
}