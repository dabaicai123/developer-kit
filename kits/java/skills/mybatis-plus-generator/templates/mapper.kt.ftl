package ${package.Mapper}

import ${package.Entity}.${entity}
import ${superMapperClassPackage}
<#if swagger>
import io.swagger.v3.oas.annotations.tags.Tag
</#if>
import org.apache.ibatis.annotations.Mapper

/**
 * <p>${table.comment} data access interface</p>
 *
 * <p>Corresponding to the ${table.name} table in the database, providing data access operations related to ${table.comment}.
 * This interface uses the MyBatis-Plus framework, inheriting BaseMapper to provide basic CRUD operations.</p>
 *
 * <p>Primary functions:
 * <ul>
 *   <li>Basic CRUD operations (inherited from BaseMapper)</li>
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
@Tag(name = "${table.comment} Management", description = "${table.comment} data access interface")
</#if>
@Mapper
interface ${table.mapperName} : ${superMapperClass}<${entity}> {
<#if customMethods??>

<#-- BEGIN Custom methods -->
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
<#-- END Custom methods -->
</#if>
}