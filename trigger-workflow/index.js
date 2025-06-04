const core = require('@actions/core');
const github = require('@actions/github');

async function main() {
    try {
        // Get inputs
        const githubToken = core.getInput('github-token', { required: true });
        const targetOwner = core.getInput('target-owner', { required: true });
        const targetRepo = core.getInput('target-repo', { required: true });
        const workflowId = core.getInput('workflow-id', { required: true });
        const workflowRef = core.getInput('workflow-ref') || 'main';
        const workflowInputsString = core.getInput('workflow-inputs') || '{}';
        
        // Parse workflow inputs
        let workflowInputs;
        try {
            workflowInputs = JSON.parse(workflowInputsString);
        } catch (parseError) {
            throw new Error(`Invalid workflow-inputs JSON: ${parseError.message}`);
        }
        
        // Configuration inputs
        const workflowVerificationTimeoutMinutes = parseInt(core.getInput('workflow-verification-timeout-minutes') || '2');
        const workflowVerificationRetryIntervalSeconds = parseInt(core.getInput('workflow-verification-retry-interval-seconds') || '10');
        const workflowVerificationBufferSeconds = parseInt(core.getInput('workflow-verification-buffer-seconds') || '30');
        const workflowCompletionTimeoutMinutes = parseInt(core.getInput('workflow-completion-timeout-minutes') || '10');
        const workflowCompletionRetryIntervalSeconds = parseInt(core.getInput('workflow-completion-retry-interval-seconds') || '10');
        const workflowRunsPerPage = parseInt(core.getInput('workflow-runs-per-page') || '10');
        
        // Initialize GitHub client
        const octokit = github.getOctokit(githubToken);
        
        // Record the current time before triggering
        const triggerTime = new Date();
        console.log(`Triggering workflow at: ${triggerTime.toISOString()}`);
        
        // Trigger the workflow
        const response = await octokit.rest.actions.createWorkflowDispatch({
            owner: targetOwner,
            repo: targetRepo,
            workflow_id: workflowId,
            ref: workflowRef,
            inputs: workflowInputs
        });
        
        console.log('Successfully triggered workflow');
        console.log(`Target: ${targetOwner}/${targetRepo}`);
        console.log(`Workflow: ${workflowId}`);
        console.log(`Ref: ${workflowRef}`);
        console.log(`Inputs:`, workflowInputs);
        
        // Wait for the workflow to be created and started
        console.log('Waiting for workflow to be created...');
        
        let workflowFound = false;
        let workflowFailed = false;
        let attempts = 0;
        const maxAttempts = Math.ceil(workflowVerificationTimeoutMinutes * (60 / workflowVerificationRetryIntervalSeconds));
        
        console.log(`Timeout configured for ${workflowVerificationTimeoutMinutes} minutes (max ${maxAttempts} attempts, ${workflowVerificationRetryIntervalSeconds}s intervals)`);
        
        while (!workflowFound && !workflowFailed && attempts < maxAttempts) {
            attempts++;
            console.log(`Verification attempt ${attempts}/${maxAttempts}`);
            
            // Wait before checking (using configurable interval)
            await new Promise(resolve => setTimeout(resolve, workflowVerificationRetryIntervalSeconds * 1000));
            
            try {
                // Get recent workflow runs to verify our workflow was created
                const workflowRuns = await octokit.rest.actions.listWorkflowRuns({
                    owner: targetOwner,
                    repo: targetRepo,
                    workflow_id: workflowId,
                    per_page: workflowRunsPerPage
                });
                
                console.log(`   Found ${workflowRuns.data.workflow_runs.length} total workflow runs`);
                console.log(`   Trigger time: ${triggerTime.toISOString()}`);
                
                // Add a configurable buffer to account for timing differences between trigger and creation
                const bufferTime = new Date(triggerTime.getTime() - (workflowVerificationBufferSeconds * 1000));
                console.log(`   Buffer time (${workflowVerificationBufferSeconds}s before trigger): ${bufferTime.toISOString()}`);
                
                // Log all recent runs for debugging
                workflowRuns.data.workflow_runs.forEach((run, index) => {
                    const runCreatedAt = new Date(run.created_at);
                    const isAfterBuffer = runCreatedAt >= bufferTime;
                    const isRelevantStatus = ['queued', 'in_progress', 'completed'].includes(run.status);
                    console.log(`   Run ${index + 1}: ID=${run.id}, Status=${run.status}, Created=${run.created_at}, After buffer=${isAfterBuffer}, Relevant status=${isRelevantStatus}`);
                });
                
                // Look for workflow runs created after our buffer time with relevant status
                const recentRuns = workflowRuns.data.workflow_runs.filter(run => {
                    const runCreatedAt = new Date(run.created_at);
                    const isAfterBuffer = runCreatedAt >= bufferTime;
                    const isRelevantStatus = ['queued', 'in_progress', 'completed'].includes(run.status);
                    return isAfterBuffer && isRelevantStatus;
                });
                
                console.log(`   Found ${recentRuns.length} relevant runs after buffer time`);
                
                if (recentRuns.length > 0) {
                    const latestRun = recentRuns[0];
                    console.log(`✅ Workflow run found!`);
                    console.log(`   Run ID: ${latestRun.id}`);
                    console.log(`   Status: ${latestRun.status}`);
                    console.log(`   Created: ${latestRun.created_at}`);
                    console.log(`   URL: ${latestRun.html_url}`);
                    
                    // Set outputs for other steps to use
                    core.setOutput('workflow-run-id', latestRun.id);
                    core.setOutput('workflow-run-url', latestRun.html_url);
                    core.setOutput('workflow-run-status', latestRun.status);
                    
                    workflowFound = true;
                    
                    // Now wait for the workflow to complete successfully
                    console.log('🔄 Waiting for workflow to complete...');
                    
                    let workflowCompleted = false;
                    let completionAttempts = 0;
                    const maxCompletionAttempts = Math.ceil(workflowCompletionTimeoutMinutes * (60 / workflowCompletionRetryIntervalSeconds));
                    
                    console.log(`Completion timeout configured for ${workflowCompletionTimeoutMinutes} minutes (max ${maxCompletionAttempts} attempts, ${workflowCompletionRetryIntervalSeconds}s intervals)`);
                    
                    while (!workflowCompleted && completionAttempts < maxCompletionAttempts) {
                        completionAttempts++;
                        console.log(`Completion check attempt ${completionAttempts}/${maxCompletionAttempts}`);
                        
                        // Wait before checking completion status
                        await new Promise(resolve => setTimeout(resolve, workflowCompletionRetryIntervalSeconds * 1000));
                        
                        try {
                            // Get the specific workflow run to check its status
                            const runDetails = await octokit.rest.actions.getWorkflowRun({
                                owner: targetOwner,
                                repo: targetRepo,
                                run_id: latestRun.id
                            });
                            
                            console.log(`   Current status: ${runDetails.data.status}, conclusion: ${runDetails.data.conclusion}`);
                            
                            if (runDetails.data.status === 'completed') {
                                workflowCompleted = true;
                                
                                if (runDetails.data.conclusion === 'success') {
                                    console.log('✅ Workflow completed successfully!');
                                    core.setOutput('workflow-run-conclusion', 'success');
                                    core.setOutput('workflow-final-status', runDetails.data.status);
                                } else {
                                    console.log(`❌ Workflow completed but failed with conclusion: ${runDetails.data.conclusion}`);
                                    console.log(`   Workflow URL: ${runDetails.data.html_url}`);
                                    core.setOutput('workflow-run-conclusion', runDetails.data.conclusion);
                                    core.setOutput('workflow-final-status', runDetails.data.status);
                                    throw new Error(`Workflow failed with conclusion: ${runDetails.data.conclusion}`);
                                }
                            } else {
                                console.log(`   Workflow still running (status: ${runDetails.data.status})...`);
                            }
                        } catch (completionError) {
                            if (completionError.message.includes('Workflow failed with conclusion')) {
                                // Re-throw workflow failure errors - don't retry these
                                console.log(`   Workflow failed - exiting completion monitoring`);
                                workflowFailed = true;
                                workflowCompleted = true; // Exit the completion loop
                                throw completionError;
                            }
                            console.log(`   Error checking workflow completion: ${completionError.message}`);
                            console.log(`   This might be due to API rate limits - will retry`);
                        }
                    }
                    
                    if (!workflowCompleted) {
                        console.log('⏱️ Workflow completion check timed out');
                        console.log(`   The workflow may still be running. Check manually: ${latestRun.html_url}`);
                        throw new Error(`Workflow completion timed out after ${workflowCompletionTimeoutMinutes} minutes`);
                    }
                } else {
                    console.log(`   No new relevant workflow runs found yet...`);
                }
            } catch (listError) {
                // Check if this is a workflow failure error that should not be retried
                if (listError.message.includes('Workflow failed with conclusion')) {
                    console.log(`   Workflow failed - stopping retries`);
                    workflowFailed = true;
                    throw listError;
                }
                console.log(`   Error checking workflow runs: ${listError.message}`);
                console.log(`   This might be due to API rate limits or permissions - will retry`);
            }
        }
        
        if (!workflowFound && !workflowFailed) {
            console.log('❌ Error: Could not find the triggered workflow within the timeout period');
            console.log('   The workflow may not have been created or there may be a delay');
            console.log('   Please check the target repository manually');
            throw new Error(`Failed to find triggered workflow within ${workflowVerificationTimeoutMinutes} minutes`);
        }
        
    } catch (error) {
        console.error('Failed to trigger and monitor workflow:', error.message);
        core.setFailed(error.message);
    }
}

main();