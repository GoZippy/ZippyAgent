# ZippyAgent Supervisor
import proxmoxer

class Supervisor:
    def __init__(self):
        self.proxmox = proxmoxer.ProxmoxAPI('host', user='user', password='pass')

if __name__ == '__main__':
    sup = Supervisor()
    print('Supervisor ready.')
