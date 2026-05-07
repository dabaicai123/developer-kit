package ${package.BO}

<#if swagger>
import io.swagger.v3.oas.annotations.media.Schema
</#if>
import java.io.Serializable

/**
 * <p>${table.comment} business object</p>
 *
 * <p>Business logic object that encapsulates ${table.comment}, containing business rules and business methods.
 * This BO is used for business layer processing, including business logic and business rule validation.</p>
 *
 * @author ${author}
 * @since ${date}
 */
<#if swagger>
@Schema(description = "${table.comment} business object")
</#if>
<#if entityLombokModel>
data class ${entity}BO(
<#else>
class ${entity}BO : Serializable {
</#if>

<#if serialVersionUID>
    companion object {
        private const val serialVersionUID: Long = 1L
    }
</#if>
## ----------  BEGIN BO fields  ----------
<#if entityLombokModel>
<#list boFields as field>
<#if field.comment?? && field.comment != "">
    /**
     * <p>${field.comment}</p>
     *
     * <p>${field.comment}, used for business logic processing</p>
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
<#list boFields as field>
<#if field.comment?? && field.comment != "">
    /**
     * <p>${field.comment}</p>
     *
     * <p>${field.comment}, used for business logic processing</p>
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
## ----------  END BO fields  ----------
<#if !entityLombokModel>
}
</#if>