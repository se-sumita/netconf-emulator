require_relative '../operation_base'
require_relative '../operation_helper'
require_relative '../datastore_manager'
require_relative '../capability_manager'

# 8.3.4.1.  <commit>
#
#   Description:
#
#         When the candidate configuration's content is complete, the
#         configuration data can be committed, publishing the data set to
#         the rest of the device and requesting the device to conform to
#         the behavior described in the new configuration.
#
#         To commit the candidate configuration as the device's new
#         current configuration, use the <commit> operation.
#
#         The <commit> operation instructs the device to implement the
#         configuration data contained in the candidate configuration.
#         If the device is unable to commit all of the changes in the
#         candidate configuration datastore, then the running
#         configuration MUST remain unchanged.  If the device does
#         succeed in committing, the running configuration MUST be
#         updated with the contents of the candidate configuration.
#
#         If the running or candidate configuration is currently locked
#         by a different session, the <commit> operation MUST fail with
#         an <error-tag> value of "in-use".
#
#         If the system does not have the :candidate capability, the
#         <commit> operation is not available.
#
#   Positive Response:
#
#         If the device was able to satisfy the request, an <rpc-reply>
#         is sent that contains an <ok> element.
#
#   Negative Response:
#
#         An <rpc-error> element is included in the <rpc-reply> if the
#         request cannot be completed for any reason.
#
module NetconfEmulator::Operation
  class Commit < Base
    def call(request)
      capability = CapabilityManager.new(@config['hello'])

      # If the system does not have the :candidate capability, the
      # <commit> operation is not available.
      return Helper::ok() unless capability.candidate_enabled?

      dsm = DatastoreManager.new(@config)
      if dsm.exist?('candidate')
        dsm.move('candidate', 'running')
      end
      if dsm.exist?('candidate-state')
        dsm.move('candidate-state', 'running-state')
      end
      Helper::ok()
    end
  end
end
