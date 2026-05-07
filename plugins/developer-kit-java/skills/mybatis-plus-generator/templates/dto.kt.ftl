package ${package.DTO}

<#if swagger>
import io.swagger.v3.oas.annotations.media.Schema
</#if>
<#if validation>
import javax.validation.constraints.*
</#if>
import java.io.Serializable
import java.time.LocalDateTime

/**
 * <p>${table.comment} ${dtoType} DTO</p>
 *
 * <p>Data transfer object for ${dtoPurpose}.
 * This DTO contains ${dtoFields} fields of ${table.comment}, used for ${dtoUsage} scenarios.</p>
 *
 * @author ${author}
 * @since ${date}
 */
<#if swagger>
@Schema(description = "${table.comment} ${dtoType} data transfer object")
</#if>
<#if entityLombokModel>
data class ${entity}${dtoType}DTO(
<#else>
class ${entity}${dtoType}DTO : Serializable {
</#if>

<#if serialVersionUID>
    companion object {
        private const val serialVersionUID: Long = 1L
    }
</#if>
## ----------  BEGIN DTO fields  ----------
<#if entityLombokModel>
<#list dtoFields as field>
<#if field.comment?? && field.comment != "">
    /**
     * <p>${field.comment}</p>
     *
     * <p>${field.comment}, ${field.type} type<#if field.propertyType == "String">, length limit of ${field.length} characters</#if></p>
     */
<#else>
    /**
     * <p>${field.propertyName}</p>
     */
</#if>
<#if swagger>
    @Schema(description = "${field.comment}"<#if field.required?? && field.required>, required = true</#if>)
</#if>
<#if validation>
<#if field.required?? && field.required>
    @get:NotNull(message = "${field.comment} cannot be empty")
<#if field.propertyType == "String">
    @get:NotBlank(message = "${field.comment} cannot be empty")
</#if>
</#if>
<#if field.propertyType == "String" && field.length??>
    @get:Size(max = ${field.length}, message = "${field.comment} length cannot exceed ${field.length} characters")
</#if>
</#if>
    var ${field.propertyName}: ${field.propertyType}<#if field.propertyType == "String">?</#if><#if field.required?? && field.required><#else> = null</#if><#if field_has_next>,</#if>

</#list>
) : Serializable
<#else>
<#list dtoFields as field>
<#if field.comment?? && field.comment != "">
    /**
     * <p>${field.comment}</p>
     *
     * <p>${field.comment}, ${field.type} type<#if field.propertyType == "String">, length limit of ${field.length} characters</#if></p>
     */
<#else>
    /**
     * <p>${field.propertyName}</p>
     */
</#if>
<#if swagger>
    @Schema(description = "${field.comment}"<#if field.required?? && field.required>, required = true</#if>)
</#if>
<#if validation>
<#if field.required?? && field.required>
    @NotNull(message = "${field.comment} cannot be empty")
<#if field.propertyType == "String">
    @NotBlank(message = "${field.comment} cannot be empty")
</#if>
</#if>
<#if field.propertyType == "String" && field.length??>
    @Size(max = ${field.length}, message = "${field.comment} length cannot exceed ${field.length} characters")
</#if>
</#if>
    var ${field.propertyName}: ${field.propertyType}<#if field.propertyType == "String">?</#if> = <#if field.required?? && field.required><#if field.propertyType == "String">null<#elseif field.propertyType == "Long" || field.propertyType == "Integer" || field.propertyType == "Int">0<#elseif field.propertyType == "Boolean">false<#else>null</#if><#else>null</#if>

</#list>
</#if>
## ----------  END DTO fields  ----------
<#if !entityLombokModel>
}
</#if>