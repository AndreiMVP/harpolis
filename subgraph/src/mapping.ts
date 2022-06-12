import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  PropertyMinted,
  PropertyTransferred,
  ProposalCreated,
} from "../generated/Harpolis/Harpolis";
import { Property, Proposal } from "../generated/schema";

export function handlePropertyMinted(event: PropertyMinted): void {
  let property = new Property(event.params.propertyId.toHex());
  property.info = event.params.info;
  property.owner = Bytes.fromI32(0);
  property.valuation = BigInt.fromI32(0);
  property.save();
}

export function handlePropertyTransferred(event: PropertyTransferred): void {
  let property = Property.load(event.params.propertyId.toHex());
  if (property == null) return;
  property.owner = event.params.newOwner;
  property.valuation = event.params.newValuation;
  property.save();
}

export function handleProposalCreated(event: ProposalCreated): void {
  let proposal = new Proposal(event.params.proposalId.toHex());
  proposal.creator = event.params.creator;
  proposal.votingClosingTime = event.params.votingClosingTime;
  proposal.description = event.params.description;
  proposal.save();
}
