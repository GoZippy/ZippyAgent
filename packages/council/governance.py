class Motion:
    def __init__(self, title, desc):
        self.title = title
        self.desc = desc
        self.status = 'pending'

class Council:
    def __init__(self, name, agents):
        self.name = name
        self.agents = agents
    def propose(self, motion):
        # TODO: discuss and vote
        motion.status = 'passed'
