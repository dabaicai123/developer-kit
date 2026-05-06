package ${package.Application}.service;

import ${package.Domain}.model.aggregate.${entity?lower_case}.${entity};
import ${package.Application}.dto.${entity}DTO;
import java.util.List;

/**
 * <p>${table.comment} application service</p>
 *
 * <p>Application service interface for ${table.comment}, located in the application layer, responsible for coordinating domain objects to complete business use cases.
 * Application services do not contain business logic; they only orchestrate domain services and aggregate roots to complete business processes.</p>
 *
 * <p>Primary responsibilities:
 * <ul>
 *   <li>Coordinate domain objects to complete business use cases</li>
 *   <li>Handle transaction boundaries</li>
 *   <li>Convert between DTOs and domain objects</li>
 *   <li>Invoke domain services and aggregate roots</li>
 *   <li>Query ${table.comment} with pagination</li>
 *   <li>Batch create ${table.comment}</li>
 *   <li>Batch update ${table.comment}</li>
 *   <li>Batch delete ${table.comment}</li>
 *   <li>Check if ${table.comment} exists</li>
 *   <li>Count ${table.comment}</li>
<#if customMethods??>
<#list customMethods as method>
 *   <li>${method.description}</li>
</#list>
</#if>
 * </ul>
 * </p>
 *
 * <p>Note: Application services should not contain business logic; business logic should be implemented in the domain layer.</p>
 *
 * @author ${author}
 * @since ${date}
 */
public interface ${entity}ApplicationService {

    /**
     * <p>Create ${table.comment}</p>
     *
     * <p>Create a new ${table.comment} aggregate root and return a DTO object.</p>
     *
     * @param ${entity?substring(0,1)?lower_case}${entity?substring(1)}DTO ${table.comment} DTO object
     * @return ${table.comment} DTO object
     */
    ${entity}DTO create${entity}(${entity}DTO ${entity?substring(0,1)?lower_case}${entity?substring(1)}DTO);

    /**
     * <p>Query ${table.comment} by ID</p>
     *
     * <p>Query ${table.comment} aggregate root by ID and convert it to a DTO for return.</p>
     *
     * @param id ${table.comment} ID
     * @return ${table.comment} DTO object
     */
    ${entity}DTO get${entity}ById(Long id);

    /**
     * <p>Update ${table.comment}</p>
     *
     * <p>Update ${table.comment} aggregate root information.</p>
     *
     * @param ${entity?substring(0,1)?lower_case}${entity?substring(1)}DTO ${table.comment} DTO object
     * @return ${table.comment} DTO object
     */
    ${entity}DTO update${entity}(${entity}DTO ${entity?substring(0,1)?lower_case}${entity?substring(1)}DTO);

    /**
     * <p>Delete ${table.comment}</p>
     *
     * <p>Delete ${table.comment} aggregate root by ID.</p>
     *
     * @param id ${table.comment} ID
     */
    void delete${entity}(Long id);

    /**
     * <p>Query all ${table.comment}</p>
     *
     * <p>Query all ${table.comment} aggregate root list and convert to DTO list for return.</p>
     *
     * @return ${table.comment} DTO list
     */
    List<${entity}DTO> getAll${entity}s();

    /**
     * <p>Query ${table.comment} with pagination</p>
     *
     * <p>Query ${table.comment} aggregate root list with pagination and convert to DTO list for return.</p>
     *
     * @param pageNum Page number (starting from 1)
     * @param pageSize Number of items per page
     * @return ${table.comment} DTO paginated list
     */
    List<${entity}DTO> get${entity}sByPage(Integer pageNum, Integer pageSize);

    /**
     * <p>Batch create ${table.comment}</p>
     *
     * <p>Batch create new ${table.comment} aggregate roots and return a DTO list.</p>
     *
     * @param ${entity?substring(0,1)?lower_case}${entity?substring(1)}DTOList ${table.comment} DTO list
     * @return ${table.comment} DTO list
     */
    List<${entity}DTO> batchCreate${entity}s(List<${entity}DTO> ${entity?substring(0,1)?lower_case}${entity?substring(1)}DTOList);

    /**
     * <p>Batch update ${table.comment}</p>
     *
     * <p>Batch update ${table.comment} aggregate root information.</p>
     *
     * @param ${entity?substring(0,1)?lower_case}${entity?substring(1)}DTOList ${table.comment} DTO list
     * @return ${table.comment} DTO list
     */
    List<${entity}DTO> batchUpdate${entity}s(List<${entity}DTO> ${entity?substring(0,1)?lower_case}${entity?substring(1)}DTOList);

    /**
     * <p>Batch delete ${table.comment}</p>
     *
     * <p>Batch delete ${table.comment} aggregate roots by ID list.</p>
     *
     * @param ids ${table.comment} ID list
     */
    void batchDelete${entity}s(List<Long> ids);

    /**
     * <p>Check if ${table.comment} exists</p>
     *
     * <p>Check if ${table.comment} aggregate root exists by ID.</p>
     *
     * @param id ${table.comment} ID
     * @return boolean whether it exists
     */
    boolean exists${entity}(Long id);

    /**
     * <p>Count ${table.comment}</p>
     *
     * <p>Count the total number of ${table.comment} aggregate roots.</p>
     *
     * @return long ${table.comment} count
     */
    long count${entity}s();
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
    ${method.returnType} ${method.name}(<#list method.parameters as param>${param.type} ${param.name}<#if param_has_next>, </#if></#list>);
</#list>
<#-- END Custom methods -->
</#if>
}