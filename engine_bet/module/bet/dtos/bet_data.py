import datetime


class BetData():
    def __int__(self, id, name, dateresult):
        self.Id = id
        self.Name = name
        self.DateResult = dateresult

    Id: int
    Name: str
    DateResult: datetime