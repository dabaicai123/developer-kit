package ${package.Domain}.service

import ${package.Domain}.model.aggregate.${entity?lower_case}.${entity}
import org.springframework.stereotype.Service

/**
 * <p>${table.comment} domain service</p>
 *
 * <p>Domain service for ${table.comment}, located in the domain layer, containing domain logic that does not belong to any aggregate root.
 * Domain services handle cross-aggregate business logic or complex business rules that are not suitable for placement in aggregate roots.</p>
 *
 * <p>Primary responsibilities:
 * <ul>
 *   <li>Handle cross-aggregate business logic</li>
 *   <li>Implement complex business rules</li>
 *   <li>Coordinate multiple aggregate roots to complete business operations</li>
<#if customMethods??>
<#list customMethods as method>
 *   <li>${method.description}</li>
</#list>
</#if>
 * </ul>
 * </p>
 *
 * <p>Note: Domain services should be stateless and should not contain persistence logic. Persistence operations should be performed through repository interfaces.</p>
 *
 * @author ${author}
 * @since ${date}
 */
@Service
class ${entity}DomainService {

    /**
     * <p>Validate ${table.comment} business rules</p>
     *
     * <p>Validate whether ${table.comment} conforms to business rules. This method contains complex business rule validation logic.</p>
     *
     * @param ${entity?substring(0,1)?lower_case}${entity?substring(1)} ${table.comment} aggregate root object
     * @return Boolean whether it conforms to business rules
     */
    fun validateBusinessRules(${entity?substring(0,1)?lower_case}${entity?substring(1)}: ${entity}): Boolean {
        TODO("Implement business rule validation for ${table.comment}")
    }

    /**
     * <p>Calculate ${table.comment} related business metrics</p>
     *
     * <p>Calculate business metrics related to ${table.comment}, such as statistics, summary data, etc.</p>
     *
     * @param ${entity?substring(0,1)?lower_case}${entity?substring(1)} ${table.comment} aggregate root object
     * @return Any? business metrics calculation result
     */
    fun calculateBusinessMetrics(${entity?substring(0,1)?lower_case}${entity?substring(1)}: ${entity}): Any? {
        TODO("Implement business metrics calculation for ${table.comment}")
    }
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
    fun ${method.name}(<#list method.parameters as param>${param.name}: ${param.type}<#if param_has_next>, </#if></#list>): ${method.returnType} {
        TODO("Not implemented: ${method.name}")
    }
</#list>
<#-- END Custom methods -->
</#if>
}