package cycles.trait;

import lue.Eg;
import lue.trait.Trait;
import lue.node.Node;
import lue.node.CameraNode;
import lue.node.Transform;
#if WITH_PHYSICS
import haxebullet.Bullet;
#end

class VehicleBody extends Trait {

#if (!WITH_PHYSICS)
	public function new() { super(); }
#else

	var physics:PhysicsWorld;
    var transform:Transform;
	var camera:CameraNode;

	// Wheels
	var wheels:Array<VehicleWheel> = [];
	var wheelNames:Array<String>;

    var m_vehicle:BtRaycastVehiclePointer = null;
    var m_carChassis:BtRigidBodyPointer;
    var startTransform:BtTransformPointer;
	
	var gEngineForce = 0.0;
	var gBreakingForce = 0.0;
	var gVehicleSteering = 0.0;

	var maxEngineForce = 3000.0;
	var maxBreakingForce = 100.0;

	public function new(wheelName1:String, wheelName2:String, wheelName3:String, wheelName4:String) {
		super();

		//wheelNames = [wheelName1, wheelName2, wheelName3, wheelName4];
		wheelNames = ["Wheel0", "Wheel1", "Wheel2", "Wheel3"];

		requestInit(init);
		requestUpdate(update);
		
		kha.input.Keyboard.get().notify(onKeyDown, onKeyUp);
	}
	
	var up = false;
	var down = false;
	var left = false;
	var right = false;
	function onKeyDown(key:kha.Key, char:String) {
		if (key == kha.Key.UP) up = true;
		else if (key == kha.Key.DOWN) down = true;
		else if (key == kha.Key.LEFT) left = true;
		else if (key == kha.Key.RIGHT) right = true;
	}

	function onKeyUp(key:kha.Key, char:String) {
		if (key == kha.Key.UP) up = false;
		else if (key == kha.Key.DOWN) down = false;
		else if (key == kha.Key.LEFT) left = false;
		else if (key == kha.Key.RIGHT) right = false;
	}

    function init() {
    	physics = Root.physics;
    	transform = node.transform;
    	camera = Node.cameras[0];

    	for (n in wheelNames) {
			wheels.push(Eg.root.getChild(n).getTrait(VehicleWheel));
		}

    	var rightIndex = 0; 
		var upIndex = 2; 
		var forwardIndex = 1;

		var wheelDirectionCS0 = BtVector3.create(0, 0, -1);
		var wheelAxleCS = BtVector3.create(1, 0, 0);

		var wheelFriction = 1000;
		var suspensionStiffness = 20.0;
		var suspensionDamping = 2.3;
		var suspensionCompression = 4.4;
		var suspensionRestLength = 0.6;
		var rollInfluence = 0.1;

		var chassisShape = BtBoxShape.create(BtVector3.create(
				transform.size.x / 2,
				transform.size.y / 2,
				transform.size.z / 2).value);

		var compound = BtCompoundShape.create();
		
		var localTrans = BtTransform.create();
		localTrans.value.setIdentity();
		localTrans.value.setOrigin(BtVector3.create(0, 0, 1).value);

		#if js
		compound.addChildShape(localTrans, chassisShape);
		#elseif cpp
		compound.value.addChildShape(localTrans.value, chassisShape);
		#end
		
		var tr = BtTransform.create();
		tr.value.setIdentity();
		tr.value.setOrigin(BtVector3.create(
			transform.pos.x,
			transform.pos.y,
			transform.pos.z).value);
		tr.value.setRotation(BtQuaternion.create(
			transform.rot.x,
			transform.rot.y,
			transform.rot.z,
			transform.rot.w).value);

		startTransform = tr; // Cpp workaround
		m_carChassis = createRigidBody(500, compound);

		// Create vehicle
		var m_tuning = BtVehicleTuning.create();
		var m_vehicleRayCaster = BtDefaultVehicleRaycaster.create(physics.world);
		m_vehicle = BtRaycastVehicle.create(m_tuning.value, m_carChassis, m_vehicleRayCaster);

		// Never deactivate the vehicle
		m_carChassis.value.setActivationState(BtCollisionObject.DISABLE_DEACTIVATION);

		// Choose coordinate system
		m_vehicle.value.setCoordinateSystem(rightIndex, upIndex, forwardIndex);

		// Add wheels
		for (w in wheels) {
			m_vehicle.value.addWheel(
					w.connectionPointCS0.value,
					wheelDirectionCS0.value,
					wheelAxleCS.value,
					suspensionRestLength,
					w.wheelRadius,
					m_tuning.value,
					w.isFrontWheel);
		}

		// Setup wheels
		for (i in 0...m_vehicle.value.getNumWheels()){
			var wheel = m_vehicle.value.getWheelInfo(i);
			wheel.m_suspensionStiffness = suspensionStiffness;
			wheel.m_wheelsDampingRelaxation = suspensionDamping;
			wheel.m_wheelsDampingCompression = suspensionCompression;
			wheel.m_frictionSlip = wheelFriction;
			wheel.m_rollInfluence = rollInfluence;
		}

		physics.world.value.addAction(m_vehicle);
    }

	function update() {

		if (m_vehicle == null) return;

		if (up) {
			gEngineForce = maxEngineForce;
		}
		else if (down) {
			gEngineForce = -maxEngineForce;
		}
		else {
			gEngineForce = 0;
			gBreakingForce = 20;
		}

		if (left) {
			gVehicleSteering = 0.2;
		}
		else if (right) {
			gVehicleSteering = -0.2;
		}
		else {
			gVehicleSteering = 0;
		}

		m_vehicle.value.applyEngineForce(gEngineForce, 2);
		m_vehicle.value.setBrake(gBreakingForce, 2);
		m_vehicle.value.applyEngineForce(gEngineForce, 3);
		m_vehicle.value.setBrake(gBreakingForce, 3);
		m_vehicle.value.setSteeringValue(gVehicleSteering, 0);
		m_vehicle.value.setSteeringValue(gVehicleSteering, 1);

		for (i in 0...m_vehicle.value.getNumWheels()) {
			// Synchronize the wheels with the chassis worldtransform
			m_vehicle.value.updateWheelTransform(i, true);
			
			// Update wheels transforms
			var trans = m_vehicle.value.getWheelTransformWS(i);
			//wheels[i].trans = trans;
			//wheels[i].syncTransform();
			var p = trans.getOrigin();
			var q = trans.getRotation();
			wheels[i].node.transform.pos.set(p.x(), p.y(), p.z());
			wheels[i].node.transform.rot.set(q.x(), q.y(), q.z(), q.w());
			wheels[i].node.transform.dirty = true;
		}

		var trans = m_carChassis.value.getWorldTransform();
		var p = trans.getOrigin();
		var q = trans.getRotation();
		transform.pos.set(p.x(), p.y(), p.z());
		transform.rot.set(q.x(), q.y(), q.z(), q.w());
		var up = transform.matrix.up();
		transform.pos.add(up);
		transform.dirty = true;

		camera.updateMatrix();
	}

	function createRigidBody(mass:Float, shape:BtCompoundShapePointer):BtRigidBodyPointer {
		
		var localInertia = BtVector3.create(0, 0, 0);
		shape.value.calculateLocalInertia(mass, localInertia.value);

		var centerOfMassOffset = BtTransform.create();
		centerOfMassOffset.value.setIdentity();
		
		var myMotionState = BtDefaultMotionState.create(startTransform.value, centerOfMassOffset.value);
		var cInfo = BtRigidBodyConstructionInfo.create(mass, myMotionState, shape, localInertia.value).value;
			
		var body = BtRigidBody.create(cInfo);
		body.value.setLinearVelocity(BtVector3.create(0, 0, 0).value);
		body.value.setAngularVelocity(BtVector3.create(0, 0, 0).value);
		physics.world.value.addRigidBody(body);

		return body;
	}
#end
}
