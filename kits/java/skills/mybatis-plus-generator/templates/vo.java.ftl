package ${package.VO};

<#if swagger>
import io.swagger.v3.oas.annotations.media.Schema;
</#if>
<#if entityLombokModel>
import lombok.Data;
</#if>
import java.io.Serializable;
import java.time.LocalDateTime;

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
@Data
</#if>
public class ${entity}VO implements Serializable {

<#if serialVersionUID>
    private static final long serialVersionUID = 1L;
</#if>
<#-- BEGIN VO fields -->
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
    private ${field.propertyType} ${field.propertyName};
</#list>
<#-- END VO fields -->
}