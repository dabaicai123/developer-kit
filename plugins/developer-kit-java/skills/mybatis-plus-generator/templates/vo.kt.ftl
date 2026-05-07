package ${package.VO}

<#if swagger>
import io.swagger.v3.oas.annotations.media.Schema
</#if>
import java.io.Serializable
import java.time.LocalDateTime

/**
 * <p>${table.comment}视图对象</p>
 * 
 * <p>用于${table.comment}的视图展示，包含${table.comment}的展示字段。
 * 本VO用于API响应，包含格式化后的数据和展示逻辑。</p>
 * 
 * @author ${author}
 * @since ${date}
 */
<#if swagger>
@Schema(description = "${table.comment}视图对象")
</#if>
<#if entityLombokModel>
data class ${entity}VO(
<#else>
class ${entity}VO : Serializable {
</#if>

<#if serialVersionUID>
    companion object {
        private const val serialVersionUID: Long = 1L
    }
</#if>
## ----------  BEGIN VO 字段  ----------
<#if entityLombokModel>
<#list voFields as field>
<#if field.comment?? && field.comment != "">
    /**
     * <p>${field.comment}</p>
     * 
     * <p>${field.comment}，用于视图展示</p>
     */
<#else>
    /**
     * <p>${field.propertyName}</p>
     */
</#if>
<#if swagger>
    @Schema(description = "${field.comment}")
</#if>
    var ${field.propertyName}: ${field.propertyType}<#if field.propertyType == "String">?</#if> = null<#if field_has_next>,</#if>

</#list>
) : Serializable
<#else>
<#list voFields as field>
<#if field.comment?? && field.comment != "">
    /**
     * <p>${field.comment}</p>
     * 
     * <p>${field.comment}，用于视图展示</p>
     */
<#else>
    /**
     * <p>${field.propertyName}</p>
     */
</#if>
<#if swagger>
    @Schema(description = "${field.comment}")
</#if>
    var ${field.propertyName}: ${field.propertyType}<#if field.propertyType == "String">?</#if> = null

</#list>
</#if>
## ----------  END VO 字段  ----------
<#if !entityLombokModel>
}
</#if>
