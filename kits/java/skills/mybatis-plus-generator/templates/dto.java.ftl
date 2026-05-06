package ${package.DTO};

<#if swagger>
import io.swagger.v3.oas.annotations.media.Schema;
</#if>
<#if entityLombokModel>
import lombok.Data;
</#if>
<#if validation>
import javax.validation.constraints.*;
</#if>
import java.io.Serializable;
import java.time.LocalDateTime;

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
@Data
</#if>
public class ${entity}${dtoType}DTO implements Serializable {

<#if serialVersionUID>
    private static final long serialVersionUID = 1L;
</#if>
<#-- BEGIN DTO fields -->
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
    private ${field.propertyType} ${field.propertyName};
</#list>
<#-- END DTO fields -->
}