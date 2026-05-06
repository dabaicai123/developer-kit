package ${package.VO}

<#if swagger>
import io.swagger.v3.oas.annotations.media.Schema
</#if>
import java.io.Serializable
import java.time.LocalDateTime

/**
 * <p>${table.comment} view object</p>
 *
 * <p>Used for ${table.comment} view presentation, containing ${table.comment} display fields.
 * This VO is used for API responses, containing formatted data and display logic.</p>
 *
 * @author ${author}
 * @since ${date}
 */
<#if swagger>
@Schema(description = "${table.comment} view object")
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
<#-- BEGIN VO fields -->
<#if entityLombokModel>
<#list voFields as field>
<#if field.comment?? && field.comment != "">
    /**
     * <p>${field.comment}</p>
     *
     * <p>${field.comment}, used for view presentation</p>
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
     * <p>${field.comment}, used for view presentation</p>
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
<#-- END VO fields -->
<#if !entityLombokModel>
}
</#if>