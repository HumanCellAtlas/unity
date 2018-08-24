module UserWorkspacesHelper
  # get actions links for a workflow submission
  def get_submission_actions(submission, user_workspace)
    actions = []
    # submission is still queued or running
    if %w(Queued Submitted Running).include?(submission['status'])
      actions << link_to("<i class='fas fa-fw fa-times'></i> Abort".html_safe, '#',
                         class: 'btn btn-sm btn-block btn-danger abort-submission',
                         title: 'Stop execution of this workflow',
                         data: {toggle: 'tooltip', id: submission['submissionId'],
                                url: abort_submission_workflow_path(project: user_workspace.namespace, name: user_workspace.name,
                                                                    submission_id: submission['submissionId']),
                                })
    end
    # submission has completed successfully
    if submission['status'] == 'Done' && submission['workflowStatuses'].keys.include?('Succeeded')
      actions << link_to("<i class='fas fa-fw fa-cloud-download-alt'></i> Outputs".html_safe, 'javascript:;',
                         class: 'btn btn-sm btn-block btn-info get-submission-outputs', title: 'Get benchmarking outputs',
                         data: {
                             toggle: 'tooltip', id: submission['submissionId'],
                             url: get_submission_outputs_path(project: user_workspace.namespace, name: user_workspace.name,
                                                              submission_id: submission['submissionId'])
                         })
    end
    # submission has failed
    if %w(Done Aborted).include?(submission['status']) && submission['workflowStatuses'].keys.include?('Failed')
      actions << link_to("<i class='fas fa-fw fa-exclamation-triangle'></i> Show Errors".html_safe, 'javascript:;',
                         class: 'btn btn-sm btn-block btn-danger get-submission-errors', title: 'View errors for this run',
                         data: {
                             toggle: 'tooltip', id: submission['submissionId'],
                             url: get_submission_workflow_path(project: user_workspace.namespace, name: user_workspace.name,
                                                              submission_id: submission['submissionId'])
                         })
    end
    # delete action to always load when completed
    if %w(Done Aborted).include?(submission['status'])
      actions << link_to("<i class='fas fa-fw fa-trash'></i> Delete Submission".html_safe, 'javascript:;',
                         class: 'btn btn-sm btn-block btn-danger delete-submission-files',
                         title: 'Remove submission from list and delete all files from submission directory',
                         data: {
                             toggle: 'tooltip', id: submission['submissionId'],
                             url: delete_submission_files_path(project: user_workspace.namespace, name: user_workspace.name,
                                                              submission_id: submission['submissionId'])
                         })
    end
    actions.join(" ").html_safe
  end

  # get a label for a workflow status code
  def submission_status_label(status)
    case status
    when 'Queued'
      label_class = 'secondary'
    when 'Submitted'
      label_class = 'info'
    when 'Running'
      label_class = 'primary'
    when 'Done'
      label_class = 'success'
    when 'Aborting'
      label_class = 'warning'
    when 'Aborted'
      label_class = 'danger'
    else
      label_class = 'dark'
    end
    "<span class='badge badge-#{label_class}'>#{status}</span>".html_safe
  end

  # get a label for a workflow status code
  def workflow_status_labels(workflow_statuses)
    labels = []
    workflow_statuses.keys.each do |status|
      case status
      when 'Submitted'
        label_class = 'info'
      when 'Launching'
        label_class = 'info'
      when 'Running'
        label_class = 'primary'
      when 'Succeeded'
        label_class = 'success'
      when 'Failed'
        label_class = 'danger'
      else
        label_class = 'secondary'
      end
      labels << "<span class='badge badge-#{label_class}'>#{status}</span>"
    end
    labels.join("<br />").html_safe
  end

  # get a UTC timestamp in local time, formatted all purty-like
  def local_timestamp(utc_time)
    Time.zone.parse(utc_time).strftime("%F %R")
  end
end
