// This file is the main file where your module's code should be implemented. It should contain the main logic of your module and the public functions that will be exposed to other modules or canisters. The file should also include any necessary imports and type definitions.
// Types for this library should be properly filed in the /migrations folder according to the version of the library. The types should be organized in a way that makes it easy to understand and maintain the code.  Do not define new types in this file.

import MigrationTypes "migrations/types";
import MigrationLib "migrations";
import ClassPlusLib "mo:class-plus";
import Buffer "mo:base/Buffer";
import Service "service";
import D "mo:base/Debug";
import Star "mo:star/star";
import ovsfixed "mo:ovs-fixed";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Error "mo:base/Error";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Timer "mo:base/Timer";
import Map "mo:map/Map";
import Log "mo:stable-local-log";



module {

  public let Migration = MigrationLib;
  public let TT = MigrationLib.TimerTool;
  public type State = MigrationTypes.State;
  public type CurrentState = MigrationTypes.Current.State;
  public type Environment = MigrationTypes.Current.Environment;
  public type InitArgs = MigrationTypes.Current.InitArgs;

  public let init = Migration.migrate;

  public func initialState() : State {#v0_0_0(#data)};
  public let currentStateVersion = #v0_1_0(#id);


  public func test() : Nat{
    1;
  };

  public func natNow() : Nat{
    Int.abs(Time.now());
  };

  public func Init<system>(config : {
    manager: ClassPlusLib.ClassPlusInitializationManager;
    initialState: State;
    args : ?InitArgs;
    pullEnvironment : ?(() -> Environment);
    onInitialize: ?(Sample -> async*());
    onStorageChange : ((State) ->())
  }) :()-> Sample {

    D.print("Subscriber Init");
    switch(config.pullEnvironment){
      case(?val) {
        D.print("pull environment has value");
        
      };
      case(null) {
        D.print("pull environment is null");
      };
    };  
    let instance = ClassPlusLib.ClassPlus<system,
      Sample, 
      State,
      InitArgs,
      Environment>({config with constructor = Sample}).get;
    
    instance().icrc85_initialize<system>(); 
    instance;
  };

  public class Sample(stored: ?State, instantiator: Principal, canister: Principal, args: ?InitArgs, environment_passed: ?Environment, storageChanged: (State) -> ()){

    public let debug_channel = {
      var announce = true;
    };

    let environment = switch(environment_passed){
      case(?val) val;
      case(null) {
        D.trap("Environment is required");
      };
    };

    let d = environment.log.log_debug;

    var state : CurrentState = switch(stored){
      case(null) {
        let #v0_1_0(#data(foundState)) = init(initialState(),currentStateVersion, null, instantiator, canister);
        foundState;
      };
      case(?val) {
        let #v0_1_0(#data(foundState)) = init(val, currentStateVersion, null, instantiator, canister);
        foundState;
      };
    };

    storageChanged(#v0_1_0(#data(state)));

    let self : Service.Service = actor(Principal.toText(canister));


    ///////////
    // ICRC85 ovs
    //////////

    private var _icrc85init = false;

    public func icrc85_initialize<system>(){
      if(_icrc85init == true) return;
      _icrc85init := true;

      ignore Timer.setTimer<system>(#nanoseconds(OneDay), scheduleCycleShare);
      environment.tt.registerExecutionListenerAsync(?"icrc85:ovs:shareaction:sample", handleIcrc85Action : TT.ExecutionAsyncHandler);
    };

    private func scheduleCycleShare<system>() : async() {
      //check to see if it already exists
      debug d("in schedule cycle share", "sample_cycle_share");
      switch(state.icrc85.nextCycleActionId){
        case(?val){
          switch(Map.get(environment.tt.getState().actionIdIndex, Map.nhash, val)){
            case(?time) {
              //already in the queue
              return;
            };
            case(null) {};
          };
        };
        case(null){};
      };



      let result = environment.tt.setActionSync<system>(Int.abs(Time.now()), ({actionType = "icrc85:ovs:shareaction:sample"; params = Blob.fromArray([]);}));
      state.icrc85.nextCycleActionId := ?result.id;
    };

    private func handleIcrc85Action<system>(id: TT.ActionId, action: TT.Action) : async* Star.Star<TT.ActionId, TT.Error>{

      D.print("in handle timer async " # debug_show((id,action)));
      switch(action.actionType){
        case("icrc85:ovs:shareaction:sample"){
          await* shareCycles<system>();
          #awaited(id);
        };
        case(_) #trappable(id);
      };
    };

    private func shareCycles<system>() : async*(){
      debug d("in share cycles", "sample_share_cycles");
      let lastReportId = switch(state.icrc85.lastActionReported){
        case(?val) val;
        case(null) 0;
      };

      debug d("last report id " # debug_show(lastReportId), "sample_share_cycles");

      let actions = if(state.icrc85.activeActions > 0){
        state.icrc85.activeActions;
      } else {1;};

      state.icrc85.activeActions := 0;

      debug d("actions " # debug_show(actions), "sample_share_cycles");

      var cyclesToShare = 1_000_000_000_000; //1 XDR

      if(actions > 0){
        let additional = Nat.div(actions, 10000);
        debug d("additional " # debug_show(additional), "sample_share_cycles");
        cyclesToShare := cyclesToShare + (additional * 1_000_000_000_000);
        if(cyclesToShare > 100_000_000_000_000) cyclesToShare := 100_000_000_000_000;
      };

      debug d("cycles to share" # debug_show(cyclesToShare), "sample_share_cycles");

      try{
        await* ovsfixed.shareCycles<system>({
          environment = do?{environment.advanced!.icrc85!};
          namespace = "com.icdevs.libraries.sample";
          actions = actions;
          schedule = func <system>(period: Nat) : async* (){
            let result = environment.tt.setActionSync<system>(Int.abs(Time.now()) + period, {actionType = "icrc85:ovs:shareaction:sample"; params = Blob.fromArray([]);});
            state.icrc85.nextCycleActionId := ?result.id;
          };
          cycles = cyclesToShare;
        });
        state.icrc85.lastActionReported := ?natNow();
      } catch(e){
        debug d("error sharing cycles" # Error.message(e), "sample_share_cycles");
      };

    };

    let OneDay =  86_400_000_000_000;


  };

};