# Agent Monitor - Stakeholder Guide

## What You'll Receive

### Daily Notifications (9:00 AM UTC)

You will receive automated updates through:
- **Slack**: Summary posted to #agent-status channel
- **Email**: Detailed report sent to your inbox

### Report Contents

Each daily report includes:
- 📊 **Overall Project Completion** percentage
- 🟢 **Agent Status** (Live/Offline/Degraded)
- 🚨 **Critical Issues** requiring immediate attention
- ⚠️ **Warnings** for potential problems
- 📈 **Performance Metrics** for each agent
- ✅ **Next Steps** and recommendations

## Understanding the Report

### Status Indicators
- 🟢 **Live**: Agent operating normally
- 🟡 **Degraded**: Agent experiencing issues but still functional
- 🔴 **Offline**: Agent not responding (critical)

### Key Metrics
- **Completion %**: Progress toward agent objectives
- **Uptime**: Percentage of time agent is operational
- **Last Log Time**: Most recent activity timestamp

## Automatic Actions

### Jira Tickets
Critical issues automatically create Jira tickets with:
- Detailed problem description
- Affected agent information
- Recommended resolution steps
- Priority: **Critical**
- Labels: `agent-monitor`, `critical-issue`

### Finding Your Tickets
1. Go to Jira
2. Search: `project = ZCAI AND labels = "agent-monitor"`
3. Or check the #agent-alerts Slack channel

## Taking Action

### For Critical Issues (🔴)
1. Check Jira for the auto-created ticket
2. Assign to appropriate team member
3. Follow recommended resolution steps
4. Update ticket status when resolved

### For Warnings (🟡)
1. Review the specific warning details
2. Assess impact on project timeline
3. Plan remediation if needed
4. Monitor for escalation

## Customizing Your Experience

### Email Preferences
Contact DevOps to:
- Add/remove recipients
- Change delivery time
- Modify report format

### Slack Notifications
- Mute channel if needed
- Set custom notification preferences
- Create filters for critical alerts only

## Report Access

### Web Portal
- URL: https://zippycoin.internal/reports
- Updated daily with latest report
- Historical reports available

### GitHub
- Repository: ZippyCoin/Core-Research/agent-monitor-app
- Path: `/reports/`
- All reports stored with timestamps

## Frequently Asked Questions

**Q: I didn't receive today's report**
A: Check spam folder, verify you're on the distribution list, or check Slack history

**Q: How do I add a new team member?**
A: Contact DevOps with their email and Slack handle

**Q: Can I get reports more frequently?**
A: Yes, we can configure hourly or custom schedules

**Q: What if I see a critical issue?**
A: A Jira ticket is automatically created - check your queue

**Q: How do I stop receiving reports?**
A: Contact DevOps to remove you from the distribution

## Emergency Contacts

For urgent issues outside business hours:
- **On-Call Engineer**: Check #oncall-schedule
- **Escalation**: Use PagerDuty integration
- **DevOps Team**: devops@zippycoin.com

## Feedback

We continuously improve our reporting. Please share:
- Missing information you'd like to see
- Format preferences
- Timing adjustments
- Any other suggestions

Contact: agent-monitor@zippycoin.com

---

*For technical setup details, see [setup-automated-delivery.md](setup-automated-delivery.md)*
