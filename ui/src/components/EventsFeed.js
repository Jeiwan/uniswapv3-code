import { ethers } from "ethers";
import { useContext, useEffect, useState } from "react";
import { MetaMaskContext } from "../contexts/MetaMask";

const PoolABI = require('../abi/Pool.json');

const getEvents = (poolContract) => {
  return poolContract.queryFilter("Mint", "earliest", "latest");
}

const subscribeToEvents = (poolContract, callback) => {
  poolContract.on("Mint", (a, b, c, d, e, f, g, event) => callback(event));
}

const renderAmount = (amount) => {
  return ethers.utils.formatUnits(amount);
}

const renderMint = (args) => {
  return (
    <span>
      <strong>Mint</strong>
      [range: [{args.tickLower}-{args.tickUpper}], amounts: [{renderAmount(args.amount0)}, {renderAmount(args.amount1)}]]
    </span>
  );
}

const renderEvent = (event, i) => {
  return (
    <li key={i}>{renderMint(event.args)}</li>
  )
}

const isMint = (event) => {
  return event.event === "Mint";
}

const EventsFeed = (props) => {
  const metamaskContext = useContext(MetaMaskContext);
  const [events, setEvents] = useState([]);
  let poolContract;

  useEffect(() => {
    if (metamaskContext.status !== 'connected') {
      return;
    }

    if (!poolContract) {
      poolContract = new ethers.Contract(
        props.config.poolAddress,
        PoolABI,
        new ethers.providers.Web3Provider(window.ethereum)
      );
    }

    getEvents(poolContract).then((events) => {
      console.log("MINTS", events);
    });

    subscribeToEvents(poolContract, (event) => setEvents(events.concat(event)));
  }, [metamaskContext.status]);

  return (
    <ul className="py-6">
      {events.reverse().filter(isMint).map(renderEvent)}
    </ul>
  );
}

export default EventsFeed;