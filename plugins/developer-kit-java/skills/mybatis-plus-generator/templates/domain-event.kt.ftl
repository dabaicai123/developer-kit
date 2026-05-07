package ${package.Domain}.model.event

import java.io.Serializable
import java.time.LocalDateTime

/**
 * <p>${eventName} domain event</p>
 *
 * <p>${eventDescription}. Domain events represent important business events that occur in the domain model.
 * Domain events are part of the domain layer, used to achieve decoupled communication between domain objects.</p>
 *
 * <p>Domain event characteristics:
 * <ul>
 *   <li>Immutability: Domain events cannot be modified after creation</li>
 *   <li>Timestamp: Records when the event occurred</li>
 *   <li>Event source: Records the aggregate root information that triggered the event</li>
 *   <li>Event data: Contains business data related to the event</li>
 * </ul>
 * </p>
 *
 * @author ${author}
 * @since ${date}
 */
data class ${eventName} private constructor(
    /**
     * <p>Event ID</p>
     *
     * <p>Unique identifier of the event</p>
     */
    val eventId: String,

    /**
     * <p>Aggregate root ID</p>
     *
     * <p>ID of the aggregate root that triggered the event</p>
     */
    val aggregateId: Long,

    /**
     * <p>Event occurrence time</p>
     *
     * <p>Timestamp recording when the event occurred</p>
     */
    val occurredOn: LocalDateTime,
## ----------  BEGIN Event data fields  ----------
<#list eventFields as field>
<#if field.comment?? && field.comment != "">
    /**
     * <p>${field.comment}</p>
     *
     * <p>${field.comment}, ${field.type} type</p>
     */
<#else>
    /**
     * <p>${field.propertyName}</p>
     */
</#if>
    val ${field.propertyName}: ${field.propertyType}<#if field.propertyType == "String">?</#if><#if field_has_next>,</#if>

</#list>
## ----------  END Event data fields  ----------
) : Serializable {

    companion object {
        private const val serialVersionUID: Long = 1L

        /**
         * <p>Create ${eventName} domain event</p>
         *
         * <p>Create a new ${eventName} domain event instance.</p>
         *
         * @param aggregateId Aggregate root ID
<#list eventFields as field>
         * @param ${field.propertyName} ${field.comment}
</#list>
         * @return ${eventName} domain event instance
         */
        fun create(aggregateId: Long<#list eventFields as field>, ${field.propertyName}: ${field.propertyType}<#if field.propertyType == "String">?</#if></#list>): ${eventName} {
            return ${eventName}(
                eventId = java.util.UUID.randomUUID().toString(),
                aggregateId = aggregateId,
                occurredOn = LocalDateTime.now(),
<#list eventFields as field>
                ${field.propertyName} = ${field.propertyName}<#if field_has_next>,</#if>
</#list>
            )
        }
    }
}