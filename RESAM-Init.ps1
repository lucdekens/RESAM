# RESAM module - enumerations

$jobStatus = @"
using System;
 
namespace RESAM
{
  [FlagsAttribute]
  public enum JobStatus {
    Unknown = -2,
    Disabled = -1,
    Scheduled = 0,
    Active = 1,
    Aborting = 2,
    Aborted = 3,
    Completed = 4,
    Failed = 5,
    FailedHalted = 6,
    Canceled = 7,
    CompletedWithErrors = 8,
    Skipped = 9,
    TimedOut = 11
  }
}
"@
Add-Type -TypeDefinition $jobStatus -Language CSharp

$jobWhatType = @"
using System;
 
namespace RESAM
{
  [FlagsAttribute]
  public enum JobWhatType {
    Module = 0,
    Project = 1,
    Runbook = 2
  }
}
"@
Add-Type -TypeDefinition $jobWhatType -Language CSharp

$jobWhoType = @"
using System;
 
namespace RESAM
{
  [FlagsAttribute]
  public enum JobWhoType {
    Agent = 0,
    Team = 1
  }
}
"@
Add-Type -TypeDefinition $jobWhoType -Language CSharp

$jobParameterType = @"
using System;
 
namespace RESAM
{
  [FlagsAttribute]
  public enum JobParameterType {
    Text = 0,
    List = 1,
    Credentials = 2,
    MultiSelectList = 3,
    MultiLineText = 4,
    Password = 5
  }
}
"@
Add-Type -TypeDefinition $jobParameterType -Language CSharp
