module UserWorkspacesHelper
  # get actions links for a workflow submission
  def get_submission_actions(submission, study)
    actions = []
    # submission is still queued or running
    if %w(Queued Submitted Running).include?(submission['status'])
      actions << link_to("<i class='fas fa-fw fa-times'></i> Abort".html_safe, '#', class: 'btn btn-xs btn-block btn-danger abort-submission', title: 'Stop execution of this workflow', data: {toggle: 'tooltip', url: '#', id: submission['submissionId']})
    end
    # submission has completed successfully
    if submission['status'] == 'Done' && submission['workflowStatuses'].keys.include?('Succeeded')
      actions << link_to("<i class='fas fa-fw fa-cloud-download-alt'></i> Outputs".html_safe, 'javascript:;', class: 'btn btn-xs btn-block btn-info view-submission-outputs', title: 'Get benchmarking outputs', data: {toggle: 'tooltip', id: submission['submissionId'], url: '#'})
    end
    # submission has failed
    if %w(Done Aborted).include?(submission['status']) && submission['workflowStatuses'].keys.include?('Failed')
      actions << link_to("<i class='fas fa-fw fa-exclamation-triangle'></i> Show Errors".html_safe, 'javascript:;', class: 'btn btn-xs btn-block btn-danger get-submission-errors', title: 'View errors for this run', data: {toggle: 'tooltip', url: '#', id: submission['submissionId']})
    end
    # delete action to always load when completed
    if %w(Done Aborted).include?(submission['status'])
      actions << link_to("<i class='fas fa-fw fa-trash'></i> Delete Submission".html_safe, 'javascript:;', class: 'btn btn-xs btn-block btn-danger delete-submission-files', title: 'Remove submission from list and delete all files from submission directory', data: {toggle: 'tooltip', url: '#', id: submission['submissionId']})
    end
    actions.join(" ").html_safe
  end
end
