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
@Data
</#if>
public class ${entity}VO implements Serializable {

<#if serialVersionUID>
    private static final long serialVersionUID = 1L;
</#if>
## ----------  BEGIN VO 字段  ----------
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
    private ${field.propertyType} ${field.propertyName};
</#list>
## ----------  END VO 字段  ----------
}
