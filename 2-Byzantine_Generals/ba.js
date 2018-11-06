/*
	@license magnet:?xt=urn:btih:0b31508aeb0634b347b8270c7bee4d411b5d4109&dn=agpl-3.0.txt
	
	Copyright (C) 2018 SabineWren
	https://github.com/SabineWren
	
	GNU AFFERO GENERAL PUBLIC LICENSE Version 3, 19 November 2007
	https://www.gnu.org/licenses/agpl-3.0.html
	
	@license-end
*/
const ORDERS = Object.freeze({
	Attack: 0,
	Retreat: 1,
});

const getMajority = function(values) {
	const attacking  = values
		.filter(value => value === ORDERS.Attack)
		.length;
	const retreating = values
		.filter(value => value === ORDERS.Retreat)
		.length;
	if(attacking > retreating) { return ORDERS.Attack; }
	return ORDERS.Retreat;
};

const getValueToSend = function(general, lt) {
	const isComplement = general.isTraitor && lt.id % 2 === 0;
	if(!isComplement) { return general.value; }
	
	if(general.value === ORDERS.Attack) { return ORDERS.Retreat; }
	return ORDERS.Attack;
};

const recFindAgreement = async function(depth, general, lieutenants) {
	//step one -- broadcast
	const broadcasted = lieutenants.map(function(lt) {
		return {
			depth: depth,
			isTraitor: lt.isTraitor,
			id: lt.id,
			value: getValueToSend(general, lt),
		};
	});
	
	//base case
	if(depth === 0) {
		return broadcasted.map(ele => ele.value);
	}
	
	//step two -- exchange
	const recurseWithNewGeneral = async function(node) {
		node.value = getMajority(broadcasted.map(ele => ele.value));
		const others = broadcasted.filter(n => n.id !== node.id);
		
		const subAgreements = await recFindAgreement(depth - 1, node, others);
		return getMajority(subAgreements);
	};
	const asyncValues = broadcasted.map(recurseWithNewGeneral);
	return await Promise.all(asyncValues);
};

const getAgreement = async function(depth, generals) {
	const general = generals[0];
	const lieutenants = generals.slice(1);
	return await recFindAgreement(depth, general, lieutenants);
};
/*
const getInput = async function() {
	
};*/

const main = async function() {
	const depth = 2;
	const generals = Object.freeze([
		{ id: 0, isTraitor: false, value: ORDERS.Attack, },
		{ id: 1, isTraitor: true, value: ORDERS.Retreat, },
		{ id: 2, isTraitor: false, value: ORDERS.Retreat, },
		{ id: 3, isTraitor: false,  value: ORDERS.Retreat, },
		{ id: 4, isTraitor: false,  value: ORDERS.Retreat, },
	]);
	
	if(depth + 3 > generals.length) { console.log("INVALID INPUT: require depth + 3 <= num generals"); }
	
	const agreement = await getAgreement(depth, generals);
	agreement.unshift(generals[0].value);
	console.log(agreement);
};
main();

