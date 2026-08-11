{{config(
    warn_if = '>= 5',
    error_if = '>= 50'
)
}}

SELECT
    messages.id AS message_id,
    messages.created_at,
    messages._airbyte_extracted_at
FROM {{ ref('stg_messages') }} messages
JOIN {{ ref('stg_conversations') }} AS conversations
    ON conversations.conversation_sk = messages.conversation_sk
WHERE messages.created_at < conversations.created_at
AND conversations.id != 'unknown_conversation'