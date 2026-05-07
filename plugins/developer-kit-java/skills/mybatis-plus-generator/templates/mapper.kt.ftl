package ${package.Mapper}

import ${package.Entity}.${entity}
import ${superMapperClassPackage}
<#if swagger>
import io.swagger.v3.oas.annotations.tags.Tag
</#if>
import org.apache.ibatis.annotations.Mapper

/**
 * <p>${table.comment}数据访问接口</p>
 * 
 * <p>对应数据库中的 ${table.name} 表，提供${table.comment}相关的数据访问操作。
 * 本接口使用 MyBatis-Plus 框架，继承 BaseMapper 提供基础的 CRUD 操作。</p>
 * 
 * <p>主要功能：
 * <ul>
 *   <li>基础的增删改查操作（继承自 BaseMapper）</li>
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
@Tag(name = "${table.comment}管理", description = "${table.comment}数据访问接口")
</#if>
@Mapper
interface ${table.mapperName} : ${superMapperClass}<${entity}> {
<#if customMethods??>

## ----------  BEGIN 自定义方法  ----------
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
## ----------  END 自定义方法  ----------
</#if>
}
