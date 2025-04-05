import Buffer "mo:base/Buffer";
import D "mo:base/Debug";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Error "mo:base/Error";


import ClassPlus "mo:class-plus";
import TT "mo:timer-tool";
import ICRC10 "mo:icrc10-mo";

import Sample ".";

shared (deployer) actor class SampleCanister<system>(
  args:?{
    sampleArgs: ?Sample.InitArgs;
    ttArgs: ?TT.InitArgList;
  }
) = this {

  let debug_channel = {
    var announce = true;
    var timerTool = true; 
  };

  transient var vecLog = Buffer.Buffer<Text>(1);

  private func d(doLog : Bool, message: Text) {
    if(doLog){
      vecLog.add( Nat.toText(Int.abs(Time.now())) # " " # message);
      if(vecLog.size() > 5000){
        vecLog := Buffer.Buffer<Text>(1);
      };
      D.print(message);
    };
  };

  let thisPrincipal = Principal.fromActor(this);
  stable var _owner = deployer.caller;

  let initManager = ClassPlus.ClassPlusInitializationManager(_owner, Principal.fromActor(this), true);


  let sampleInitArgs = do?{args!.sampleArgs!};
  let ttInitArgs : ?TT.InitArgList = do?{args!.ttArgs!};

  stable var icrc10 = ICRC10.initCollection();

  private func reportTTExecution(execInfo: TT.ExecutionReport): Bool{
    debug if(debug_channel.timerTool) D.print("CANISTER: TimerTool Execution: " # debug_show(execInfo));
    return false;
  };

  private func reportTTError(errInfo: TT.ErrorReport) : ?Nat{
    debug if(debug_channel.timerTool) D.print("CANISTER: TimerTool Error: " # debug_show(errInfo));
    return null;
  };

  stable var tt_migration_state: TT.State = TT.Migration.migration.initialState;

  let tt  = TT.Init<system>({
    manager = initManager;
    initialState = tt_migration_state;
    args = ttInitArgs;
    pullEnvironment = ?(func() : TT.Environment {
      {      
        advanced = null;
        reportExecution = ?reportTTExecution;
        reportError = ?reportTTError;
        syncUnsafe = null;
        reportBatch = null;
      };
    });

    onInitialize = ?(func (newClass: TT.TimerTool) : async* () {
      D.print("Initializing TimerTool");
      newClass.initialize<system>();
      //do any work here necessary for initialization
    });
    onStorageChange = func(state: TT.State) {
      tt_migration_state := state;
    }
  });

  stable var sample_migration_state: Sample.State = Sample.initialState();

  let sample = Sample.Init<system>({
    manager = initManager;
    initialState = sample_migration_state;
    args = sampleInitArgs;
    pullEnvironment = ?(func() : Sample.Environment {
      {
        tt = tt();
        advanced = null; // Add any advanced options if needed
      };
    });

    onInitialize = ?(func (newClass: Sample.
    Sample) : async* () {
      D.print("Initializing Sample Class");
      //do any work here necessary for initialization
    });

    onStorageChange = func(state: Sample.State) {
      sample_migration_state := state;
    }
  });


  public shared func hello(): async Text {
    return "world!";
  }


};
