# Setting Up Automated Report Delivery

This guide explains how to configure automated daily agent status reports with notifications via Slack/Email and automatic Jira ticket creation for critical issues.

## Overview

The automated delivery system consists of:
1. **Daily Report Generation** - Automated via GitHub Actions
2. **Slack/Email Notifications** - Summary sent to stakeholders
3. **Jira Integration** - Critical issues automatically create tickets
4. **Report Hosting** - Reports available via internal web portal

## Prerequisites

- GitHub repository with Actions enabled
- Slack workspace with incoming webhooks
- Email SMTP server access
- Jira Cloud or Server instance
- Python 3.8+ installed

## Configuration Steps

### 1. GitHub Secrets Setup

Navigate to your repository Settings > Secrets and variables > Actions, and add the following secrets:

#### Slack Configuration
- `SLACK_WEBHOOK_URL` - Your Slack incoming webhook URL
  - Get from: Slack App Directory > Incoming Webhooks
  - Format: `https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX`

#### Email Configuration
- `EMAIL_SMTP_SERVER` - SMTP server address (e.g., `smtp.gmail.com`)
- `EMAIL_SMTP_PORT` - SMTP port (e.g., `587` for TLS)
- `EMAIL_FROM` - Sender email address
- `EMAIL_PASSWORD` - Email account password or app-specific password
- `EMAIL_TO` - Comma-separated list of recipient emails

#### Jira Configuration
- `JIRA_URL` - Your Jira instance URL (e.g., `https://yourcompany.atlassian.net`)
- `JIRA_PROJECT_KEY` - Project key for creating tickets (e.g., `ZCAI`)
- `JIRA_EMAIL` - Email associated with Jira API access
- `JIRA_API_TOKEN` - Jira API token
  - Create at: https://id.atlassian.com/manage-profile/security/api-tokens
- `JIRA_ASSIGNEE` - (Optional) Default assignee account ID

#### Report Hosting
- `REPORT_URL` - URL where reports will be accessible
- `DEPLOY_WEBHOOK` - (Optional) Webhook for deploying reports
- `DEPLOY_TOKEN` - (Optional) Authentication token for deployment

### 2. Local Testing

Before enabling automated runs, test the scripts locally:

```bash
# Test report generation
cd src-tauri
cargo run -- generate-report

# Test notifications (set environment variables first)
export SLACK_WEBHOOK_URL="your-webhook-url"
export EMAIL_FROM="your-email@company.com"
# ... set other required variables

cd scripts
python send_notifications.py

# Test Jira integration
export JIRA_URL="https://yourcompany.atlassian.net"
export JIRA_EMAIL="your-email@company.com"
export JIRA_API_TOKEN="your-api-token"
# ... set other required variables

python create_jira_tickets.py
```

### 3. Customizing the Schedule

The workflow runs daily at 9:00 AM UTC by default. To change:

Edit `.github/workflows/daily-agent-report.yml`:
```yaml
on:
  schedule:
    - cron: '0 9 * * *'  # Modify this line
```

Cron format: `minute hour day month weekday`

Examples:
- `0 6 * * *` - Daily at 6:00 AM UTC
- `0 9 * * 1-5` - Weekdays at 9:00 AM UTC
- `0 */6 * * *` - Every 6 hours

### 4. Manual Trigger

You can manually trigger the workflow:
1. Go to Actions tab in GitHub
2. Select "Daily Agent Status Report"
3. Click "Run workflow"

### 5. Slack Message Customization

Edit `scripts/send_notifications.py` to customize the Slack message format:

```python
blocks = [
    {
        "type": "header",
        "text": {
            "type": "plain_text",
            "text": "Your custom header"
        }
    },
    # Add more blocks as needed
]
```

### 6. Email Template Customization

Modify the HTML template in `scripts/send_notifications.py`:

```python
html = f"""
<html>
  <body>
    <!-- Your custom HTML -->
  </body>
</html>
"""
```

### 7. Jira Ticket Customization

Adjust ticket creation in `scripts/create_jira_tickets.py`:

```python
payload = {
    "fields": {
        "project": {"key": JIRA_PROJECT_KEY},
        "summary": summary,
        "description": description,
        "issuetype": {"name": "Bug"},  # Change issue type
        "priority": {"name": "Critical"},  # Change priority
        "labels": ["agent-monitor", "critical-issue"],  # Add custom labels
        # Add custom fields as needed
    }
}
```

## Monitoring and Troubleshooting

### Check Workflow Status
1. Go to GitHub repository > Actions tab
2. View workflow runs and their status
3. Click on a run to see detailed logs

### Common Issues

#### Slack notifications not sending
- Verify webhook URL is correct
- Check Slack app permissions
- Look for error messages in workflow logs

#### Email delivery failures
- Verify SMTP settings
- Check if app-specific password is needed (Gmail)
- Ensure firewall allows SMTP connections

#### Jira ticket creation errors
- Verify API token has correct permissions
- Check project key exists
- Ensure issue type and fields are valid

### Debug Mode

Add debug output to scripts:

```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

## Security Best Practices

1. **Never commit secrets** - Always use GitHub Secrets
2. **Rotate credentials regularly** - Update API tokens periodically
3. **Use least privilege** - Grant minimal required permissions
4. **Monitor access logs** - Check Jira/Slack audit logs
5. **Encrypt sensitive data** - Use HTTPS for all communications

## Advanced Configuration

### Multiple Environments

Create separate workflows for different environments:

```yaml
# .github/workflows/daily-agent-report-staging.yml
env:
  JIRA_PROJECT_KEY: ${{ secrets.STAGING_JIRA_PROJECT_KEY }}
  # ... other staging-specific secrets
```

### Conditional Notifications

Only send notifications when critical issues exist:

```python
if critical_issues:
    send_slack_notification(report_name, summary)
```

### Custom Report Formats

Generate reports in multiple formats:

```bash
./agent-monitor generate-report --format=md
./agent-monitor generate-report --format=json
./agent-monitor generate-report --format=html
```

## Maintenance

### Weekly Tasks
- Review created Jira tickets
- Check notification delivery rates
- Monitor workflow execution times

### Monthly Tasks
- Update dependencies
- Review and optimize report generation
- Audit access permissions

### Quarterly Tasks
- Rotate API credentials
- Review stakeholder list
- Update notification templates

## Support

For issues or questions:
1. Check workflow logs in GitHub Actions
2. Review this documentation
3. Contact the DevOps team
4. Create an issue in the repository

---

*Last updated: 2025-01-15*
