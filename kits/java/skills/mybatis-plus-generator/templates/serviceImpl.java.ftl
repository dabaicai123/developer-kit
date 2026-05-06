package ${package.ServiceImpl};

import ${package.Entity}.${entity};
import ${package.Mapper}.${table.mapperName};
import ${package.Service}.${table.serviceName};
import ${superServiceImplClassPackage};
import org.springframework.stereotype.Service;
<#if swagger>
import io.swagger.v3.oas.annotations.tags.Tag;
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
public class ${table.serviceImplName} extends ${superServiceImplClass}<${table.mapperName}, ${entity}> implements ${table.serviceName} {

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
    @Override
    public ${method.returnType} ${method.name}(<#list method.parameters as param>${param.type} ${param.name}<#if param_has_next>, </#if></#list>) {
<#if method.parameters??>
<#list method.parameters as param>
        if (${param.name} == null<#if param.type == "String"> || ${param.name}.isEmpty()</#if>) {
            throw new IllegalArgumentException("${param.description} cannot be empty");
        }
</#list>
</#if>
        throw new UnsupportedOperationException("Not implemented: ${method.name}");
    }
</#list>
<#-- END Custom method implementations -->
</#if>
}