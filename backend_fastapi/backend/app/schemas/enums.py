from enum import Enum

class GenderEnum(str, Enum):
    male = "male"
    female = "female"
    other = "other"

class VehicleTypeEnum(str, Enum):
    two_wheeler = "2_wheeler"
    four_wheeler = "4_wheeler"

class RideStatusEnum(str, Enum):
    open = "open"
    ongoing = "ongoing"
    completed = "completed"
    cancelled = "cancelled"

class RideRequestStatusEnum(str, Enum):
    pending = "pending"
    accepted = "accepted"
    rejected = "rejected"

class AllowedGenderEnum(str, Enum):
    any = "any"
    male = "male"
    female = "female"
