class SessionAwareSLMRegistry:
    def __init__(self):
        self._slm_dict = {i:{} for i in range(1,38)}
    def get_slm(self,i): return self._slm_dict.get(i)
