import { ethers } from "ethers";
import { useContext, useEffect, useReducer } from "react";
import { MetaMaskContext } from "../contexts/MetaMask";

const PoolABI = require('../abi/Pool.json');

const getEvents = (pool) => {
  return Promise.all([
    pool.queryFilter("Burn", "earliest", "latest"),
    pool.queryFilter("Collect", "earliest", "latest"),
    pool.queryFilter("Mint", "earliest", "latest"),
    pool.queryFilter("Swap", "earliest", "latest"),
  ]).then(([mints, swaps]) => {
    return Promise.resolve((mints || []).concat(swaps || []))
  })
}

const subscribeToEvents = (pool, callback) => {
  pool.on("Burn", (a, b, c, d, e, f, g, event) => callback(event));
  pool.on("Collect", (a, b, c, d, e, f, g, event) => callback(event));
  pool.on("Mint", (a, b, c, d, e, f, g, event) => callback(event));
  pool.on("Swap", (a, b, c, d, e, f, g, event) => callback(event));
}

const renderAmount = (amount) => {
  return ethers.utils.formatUnits(amount);
}

const renderBurn = (args) => {
  return (
    <span>
      <strong>Burn</strong>
      [amount0: {renderAmount(args.amount0)}, amount1: {renderAmount(args.amount1)}, amount: {renderAmount(args.amount)}]
    </span>
  );
}

const renderCollect = (args) => {
  return (
    <span>
      <strong>Collect</strong>
      [amount0: {renderAmount(args.amount0)}, amount1: {renderAmount(args.amount1)}]
    </span>
  );
}

const renderMint = (args) => {
  return (
    <span>
      <strong>Mint</strong>
      [range: [{args.tickLower}-{args.tickUpper}], amounts: [{renderAmount(args.amount0)}, {renderAmount(args.amount1)}]]
    </span>
  );
}

const renderSwap = (args) => {
  return (
    <span>
      <strong>Swap</strong>
      [amount0: {renderAmount(args.amount0)}, amount1: {renderAmount(args.amount1)}]
    </span>
  );
}

const renderEvent = (event, i) => {
  let content;

  switch (event.event) {
    case 'Burn':
      content = renderBurn(event.args);
      break;

    case 'Collect':
      content = renderCollect(event.args);
      break;

    case 'Mint':
      content = renderMint(event.args);
      break;

    case 'Swap':
      content = renderSwap(event.args);
      break;

    default:
      return;
  }

  return (
    <tr key={i}>
      <td className="pr-2">{event.pairID}</td>
      <td>{content}</td>
    </tr>
  )
}

const isSupportedEvent = (event) => {
  return event.event === "Mint" || event.event === 'Swap' || event.event === 'Burn' || event.event === 'Collect';
}

const cleanEvents = (events) => {
  const eventsMap = events.reduce((acc, event) => {
    acc[`${event.address}_${event.transactionHash}`] = event;
    return acc;
  }, {});

  return Object.keys(eventsMap)
    .map(k => eventsMap[k])
    .sort((a, b) => b.blockNumber - a.blockNumber || b.logIndex - a.logIndex);
}

const eventsReducer = (state, action) => {
  switch (action.type) {
    case 'add':
      return cleanEvents(state.concat(action.value));

    default:
      return;
  }
}


const EventsList = ({ events }) => {
  return (
    <table className="py-6 mb-2">
      <tbody>
        {events.filter(isSupportedEvent).map(renderEvent)}
      </tbody>
    </table>
  )
}

const pairID = (pair) => `${pair.token0.symbol}/${pair.token1.symbol}`;
const addPairIDToEvents = (events, pair) => events
  .filter(ev => ev)
  .map(ev => { ev.pairID = pairID(pair); return ev });

const EventsFeed = ({ pairs }) => {
  const metamaskContext = useContext(MetaMaskContext);
  const [events, setEvents] = useReducer(eventsReducer, []);

  useEffect(() => {
    if (metamaskContext.status !== 'connected') {
      return;
    }

    const pairContracts = pairs.map((pair) => {
      const contract = new ethers.Contract(
        pair.address,
        PoolABI,
        new ethers.providers.Web3Provider(window.ethereum)
      );

      subscribeToEvents(
        contract,
        event => setEvents({
          type: 'add',
          value: addPairIDToEvents([event], pair)
        })
      );
      getEvents(contract)
        .then(events => setEvents({
          type: 'add',
          value: addPairIDToEvents(events, pair)
        }));

      return contract;
    });

    return () => {
      pairContracts.forEach((pair) => pair.removeAllListeners());
    };
  }, [metamaskContext.status, setEvents, pairs]);

  return (<EventsList events={events} />);
}

export default EventsFeed;