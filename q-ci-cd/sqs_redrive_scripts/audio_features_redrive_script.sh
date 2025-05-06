#!/bin/bash

DLQ_URL="https://sqs.us-east-1.amazonaws.com/608104255617/audio-features-dlq"
ORIGINAL_QUEUE_URL="https://sqs.us-east-1.amazonaws.com/608104255617/audio-features"
PROFILE="jenkins_service_account"
MAX_MESSAGES=10
WAIT_TIME_SECONDS=1 # You can adjust this value to control the frequency of receive attempts

# Define a function to process messages
process_messages() {
  while true; do
      # Receive messages from DLQ
      messages=$(aws sqs receive-message --queue-url $DLQ_URL --max-number-of-messages $MAX_MESSAGES --wait-time-seconds $WAIT_TIME_SECONDS --profile $PROFILE)

      # Check if there are any messages
      if [ -z "$(echo $messages | jq -r '.Messages[] | @text')" ]; then
          echo "No more messages in DLQ."
          break
      fi

      # Iterate over each message
      echo $messages | jq -c '.Messages[]' | while read -r message; do
          message_body=$(echo $message | jq -r '.Body')
          receipt_handle=$(echo $message | jq -r '.ReceiptHandle')

          # Send message to original queue and suppress output
          aws sqs send-message --queue-url $ORIGINAL_QUEUE_URL --message-body "$message_body" --profile  $PROFILE > /dev/null

          # Delete message from DLQ after sending it
          aws sqs delete-message --queue-url $DLQ_URL --receipt-handle "$receipt_handle" --profile $PROFILE
      done
  done
}

process_messages

