  variable "hosted_zone_id" {
    type = string
    description = "The ID of the hosted zone"

  }

  variable "record_name" {
    type = string
    description = "The name of the record"
    
  }
  
  variable "alias_name" {
    type = string   
    description = "The name of the alias"
   
  }

  variable "alias_zone_id" {
    type = string   
    description = "The zone ID of the alias"
  
  }
  
  variable "evaluate_target_health" {
    type = bool
    description = "Whether to evaluate the target health"
    
  }

