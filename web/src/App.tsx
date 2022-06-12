import React, { useEffect, useState } from "react";
import { useWeb3React } from "@web3-react/core";
import { injected } from "utils/connectors";
import { shortenAddress } from "utils/address";
import { Web3Provider } from "@ethersproject/providers";
import "./style.pcss";
import { getSdk } from "generated/graphql";
import { GraphQLClient } from "graphql-request";

const textShadow = [...Array(800)].reduce(
  (acc, _, i) => acc + (acc ? "," : "") + i + "px " + i + "px 0 #C2CFCE",
  ""
);

const api = getSdk(
  new GraphQLClient(
    "https://api.thegraph.com/subgraphs/name/andreimvp/harpolis"
  )
);

interface PropertyInterface {
  id: string;
  owner: any;
  valuation: any;
  info: string;
}

interface ProposalInterface {
  id: string;
  creator: any;
  votingClosingTime: any;
  description: string;
}

const App: React.FC = () => {
  const { account, activate } = useWeb3React<Web3Provider>();
  const [properties, setProperties] = useState<Array<PropertyInterface>>([]);
  const [proposals, setProposals] = useState<Array<ProposalInterface>>([]);

  const fetchProperties = async () => {
    setProperties((await api.Properties()).properties);
  };

  const fetchProposals = async () => {
    setProposals((await api.Proposals()).proposals);
  };

  useEffect(() => {
    fetchProperties();
    fetchProposals();
  }, []);

  return (
    <>
      <div className="flex flex-col items-end mr-16">
        <span
          className="text-giga text-teal-900 font-sans"
          style={{ textShadow }}
        >
          HARPOLIS
        </span>
        <span>
          {!!account && "Citizen"}
          <button
            className="text-teal-900 font-sans text-lg underline underline-offset-8 ml-4"
            onClick={() => activate(injected)}
          >
            {!!account ? shortenAddress(account) : "Connect"}
          </button>
        </span>
      </div>

      <span className="m-12 text-3xl">Properties</span>
      <div className="p-12 w-4/5">
        {properties.length && (
          <div className="grid gap-4 grid-cols-2">
            {properties.map((property) => (
              <div
                key={property.info}
                className="border rounded-lg flex flex-col p-4"
              >
                <span className="text-sm">
                  <strong>ID </strong>
                  {property.id}
                </span>
                <span className="text-xl font-bold">{property.info}</span>
                <span>
                  <strong>Owner </strong>
                  {property.owner}
                </span>
                <span>
                  <strong>Valuation </strong>
                  {property.valuation}
                  <strong> HAR</strong>
                </span>
                <div className="flex justify-end">
                  <button className="border rounded p-3 hover:bg-teal-900 hover:text-white">
                    ⚡BUY
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      <span className="m-12 text-3xl">Proposals</span>
      <div className="p-12 w-4/5">
        {proposals.length && (
          <div className="grid gap-4 grid-cols-2">
            {proposals.map((proposal) => (
              <div
                key={proposal.id}
                className="border rounded-lg flex flex-col p-4"
              >
                <span className="text-sm">
                  <strong>ID </strong>
                  {proposal.id}
                </span>
                <span className="text-xl font-bold">
                  {proposal.description}
                </span>
                <span>
                  <strong>Creator </strong>
                  {proposal.creator}
                </span>
                <span>
                  <strong>Voting deadline </strong>
                  {proposal.votingClosingTime}
                </span>
                <div className="flex justify-end">
                  <button className="border rounded p-3 mx-2 hover:bg-teal-900 hover:text-white">
                    👍YES
                  </button>
                  <button className="border rounded p-3 hover:bg-teal-900 hover:text-white">
                    👎NO
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </>
  );
};

export default App;
