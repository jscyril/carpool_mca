import enum

class GenderEnum(str, enum.Enum):
    male = "male"
    female = "female"
    other = "other"

class VehicleTypeEnum(str, enum.Enum):
    two_wheeler = "2_wheeler"
    four_wheeler = "4_wheeler"

class RideStatusEnum(str, enum.Enum):
    open = "open"
    ongoing = "ongoing"
    completed = "completed"
    cancelled = "cancelled"

class RideRequestStatusEnum(str, enum.Enum):
    pending = "pending"
    accepted = "accepted"
    rejected = "rejected"

class AllowedGenderEnum(str, enum.Enum):
    any = "any"
    male = "male"
    female = "female"

class VerificationStatusEnum(str, enum.Enum):
    pending = "pending"
    submitted = "submitted"
    verified = "verified"
    rejected = "rejected"
